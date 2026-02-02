class StatementProcessingService
  def initialize(company, user, api_key: nil)
    @company = company
    @user = user
    @api_key = api_key
    @errors = []
    @steps = {}
  end

  # Full pipeline: parse → import → reconcile
  # Returns structured result hash
  def process(file_content:, filename:, account_id: nil, account_name: nil,
              statement_balance: nil, statement_date: nil, parser: nil)
    # Step 1: Parse
    parse_result = run_parse(file_content, filename, parser)
    return failure_response('parse') unless parse_result

    # Step 2: Resolve account
    account = run_resolve_account(account_id, account_name, parse_result)
    return partial_response unless account

    # Step 3: Import transactions
    import_result = run_import(parse_result, account)
    return partial_response unless import_result

    # Step 4: Auto-reconcile
    effective_balance = statement_balance || parse_result[:statement_ending_balance]
    effective_date = statement_date || detect_statement_date(parse_result)
    run_reconcile(account, import_result[:upload], effective_balance, effective_date)

    build_response
  end

  private

  def run_parse(file_content, filename, parser)
    step = { status: 'in_progress' }
    @steps[:parse] = step

    parser_service = StatementParser.new(@company)

    # Force parser engine if specified
    result = if parser == 'kimi' && parser_service.send(:openrouter_api_key).present?
               parser_service.send(:parse_pdf_with_kimi, file_content, filename)
             elsif parser == 'claude' && parser_service.send(:anthropic_api_key).present?
               parser_service.send(:parse_pdf_with_claude, file_content, filename)
             elsif parser == 'openai'
               text = parser_service.send(:extract_pdf_text, file_content)
               if text.present?
                 parser_service.send(:ai_parse_statement, text, filename)
               else
                 { success: false, error: 'Could not extract text from PDF' }
               end
             else
               parser_service.parse(file_content, filename)
             end

    unless result[:success]
      step[:status] = 'failed'
      step[:error] = result[:error] || 'Parse failed'
      @errors << "Parse: #{step[:error]}"
      return nil
    end

    step[:status] = 'completed'
    step[:transactions_found] = result[:count]
    step[:account_name_detected] = result[:account_name]
    step[:account_type_detected] = result[:account_type]
    step[:statement_ending_balance] = result[:statement_ending_balance]
    step[:statement_period] = result[:statement_period]
    step[:parser_engine] = result[:parser_engine] || result[:format]

    result
  end

  def run_resolve_account(account_id, account_name, parse_result)
    step = { status: 'in_progress' }
    @steps[:account] = step

    account = nil

    if account_id.present?
      account = @company.accounts.find_by(id: account_id)
    end

    if account.nil? && account_name.present?
      account = @company.accounts.find_by('LOWER(name) = ?', account_name.downcase)
    end

    # Try detected account name from parsing
    if account.nil? && parse_result[:account_name].present?
      account = @company.accounts.find_by('LOWER(name) LIKE ?', "%#{parse_result[:account_name].downcase}%")
    end

    # Create account if not found but we have a name
    if account.nil?
      name = account_name || parse_result[:account_name] || 'Imported Account'
      account_type = parse_result[:account_type] || 'checking'
      # Normalize account_type to valid enum
      account_type = 'checking' unless Account.account_types.key?(account_type)

      account = @company.accounts.create!(
        name: name,
        account_type: account_type
      )
      step[:created] = true
    end

    step[:status] = 'completed'
    step[:account_id] = account.id
    step[:account_name] = account.name

    account
  rescue => e
    step[:status] = 'failed'
    step[:error] = e.message
    @errors << "Account: #{e.message}"
    nil
  end

  def run_import(parse_result, account)
    step = { status: 'in_progress' }
    @steps[:import] = step

    # Create StatementUpload record
    upload = @company.statement_uploads.create!(
      user: @user,
      account: account,
      filename: 'agent_upload.pdf',
      file_type: 'pdf',
      status: 'parsed',
      transactions_found: parse_result[:count],
      raw_data: { 'transactions' => parse_result[:transactions] },
      parse_notes: parse_result[:notes],
      source: 'agent',
      parser_engine: parse_result[:parser_engine] || parse_result[:format],
      api_key: @api_key
    )

    # Import via StatementParser
    parser = StatementParser.new(@company)
    result = parser.import(upload, account)

    step[:status] = 'completed'
    step[:transactions_imported] = result[:imported]
    step[:transactions_categorized] = result[:categorized]
    step[:duplicates_skipped] = result[:skipped_duplicates]

    { upload: upload, result: result }
  rescue => e
    step[:status] = 'failed'
    step[:error] = e.message
    @errors << "Import: #{e.message}"
    nil
  end

  def run_reconcile(account, upload, statement_balance, statement_date)
    step = { status: 'in_progress' }
    @steps[:reconciliation] = step

    unless statement_balance.present?
      step[:status] = 'skipped'
      step[:reason] = 'No statement balance provided or detected'
      return
    end

    statement_balance = statement_balance.to_f
    statement_date = statement_date || Date.current

    recon_service = ReconciliationService.new(@company, @user)

    # Start reconciliation
    start_result = recon_service.start(
      account_id: account.id,
      statement_date: statement_date,
      statement_balance: statement_balance
    )

    recon = start_result[:reconciliation]
    recon.update!(source: 'agent', statement_upload: upload)

    # Auto-clear all uncleared transactions up to statement date
    uncleared = account.account_transactions
      .where('date <= ?', statement_date)
      .where(reconciliation_status: 'uncleared')

    cleared_count = 0
    uncleared.find_each do |txn|
      txn.update!(reconciliation_status: 'cleared', reconciliation_id: recon.id)
      cleared_count += 1
    end

    recon.recalculate!

    # Auto-complete if balanced
    if recon.difference.zero?
      finish_result = recon_service.finish(reconciliation_id: recon.id)
      step[:status] = 'completed'
      step[:auto_completed] = true
    else
      step[:status] = 'completed'
      step[:auto_completed] = false
    end

    step[:reconciliation_id] = recon.id
    step[:difference] = recon.difference.to_f
    step[:transactions_cleared] = cleared_count
    step[:statement_balance] = statement_balance
    step[:book_balance] = recon.book_balance.to_f
  rescue => e
    step[:status] = 'failed'
    step[:error] = e.message
    @errors << "Reconciliation: #{e.message}"
  end

  def detect_statement_date(parse_result)
    # Try to get the last transaction date or parse from statement_period
    if parse_result[:transactions]&.any?
      dates = parse_result[:transactions].map { |t| Date.parse(t['date']) rescue nil }.compact
      dates.max
    end
  end

  def build_response
    success = @errors.empty?
    partial = @errors.any? && @steps.values.any? { |s| s[:status] == 'completed' }

    {
      success: success,
      partial: partial,
      steps: @steps,
      errors: @errors,
      summary: build_summary
    }
  end

  def failure_response(failed_step)
    build_response
  end

  def partial_response
    build_response
  end

  def build_summary
    parts = []

    if @steps[:parse]&.dig(:status) == 'completed'
      parts << "Parsed #{@steps[:parse][:transactions_found]} transactions"
    end

    if @steps[:import]&.dig(:status) == 'completed'
      imp = @steps[:import]
      details = []
      details << "imported #{imp[:transactions_imported]}"
      details << "#{imp[:duplicates_skipped]} duplicates skipped" if imp[:duplicates_skipped].to_i > 0
      details << "#{imp[:transactions_categorized]} auto-categorized" if imp[:transactions_categorized].to_i > 0
      parts << details.join(', ')
    end

    if @steps[:reconciliation]&.dig(:status) == 'completed'
      rec = @steps[:reconciliation]
      if rec[:auto_completed]
        parts << "reconciliation completed (#{rec[:transactions_cleared]} cleared, balance matched)"
      else
        parts << "reconciliation in progress (#{rec[:transactions_cleared]} cleared, difference: $#{rec[:difference].abs})"
      end
    elsif @steps[:reconciliation]&.dig(:status) == 'skipped'
      parts << "reconciliation skipped (no balance provided)"
    end

    parts.join('; ') + '.'
  end
end
