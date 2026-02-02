require 'csv'
require 'json'
require 'net/http'

class DataImporter
  SUPPORTED_SOURCES = %w[
    quickbooks_online quickbooks_desktop xero freshbooks wave
    generic_csv generic_excel ofx_qfx
  ].freeze

  def initialize(company, user)
    @company = company
    @user = user
  end

  # ============================================
  # AUTO-DETECT FORMAT
  # ============================================

  def detect_format(content, filename)
    ext = File.extname(filename).downcase

    case ext
    when '.iif'
      { source: 'quickbooks_desktop', format: 'iif', confidence: 100 }
    when '.qbo'
      { source: 'quickbooks_online', format: 'qbo_ofx', confidence: 100 }
    when '.qbx', '.qbb', '.qbw'
      { source: 'quickbooks_desktop', format: 'qb_backup', confidence: 100,
        note: 'QuickBooks backup files need to be exported as IIF or CSV first.' }
    when '.ofx', '.qfx'
      { source: 'ofx_qfx', format: 'ofx', confidence: 100 }
    when '.xls', '.xlsx'
      { source: detect_csv_source(content), format: 'excel', confidence: 70 }
    when '.csv'
      detect_csv_format(content)
    when '.json'
      detect_json_format(content)
    else
      { source: 'generic_csv', format: 'unknown', confidence: 30 }
    end
  end

  # ============================================
  # FULL IMPORT PIPELINE
  # ============================================

  # Master import: detect → parse → map → preview → import
  def import(content, filename, options = {})
    format = detect_format(content, filename)
    
    # Parse based on detected format
    parsed = case format[:source]
    when 'quickbooks_online' then parse_qbo(content, format[:format])
    when 'quickbooks_desktop' then parse_qb_desktop(content, format[:format])
    when 'xero' then parse_xero(content)
    when 'freshbooks' then parse_freshbooks(content)
    when 'wave' then parse_wave(content)
    when 'ofx_qfx' then parse_ofx(content)
    else parse_generic_csv(content)
    end

    # AI-enhance: map categories, detect accounts, suggest COA changes
    if options[:ai_enhance] != false
      parsed = ai_enhance(parsed)
    end

    # Return preview (don't commit yet)
    {
      source: format,
      summary: {
        transactions: parsed[:transactions]&.size || 0,
        accounts: parsed[:accounts]&.size || 0,
        chart_of_accounts: parsed[:chart_of_accounts]&.size || 0,
        vendors: parsed[:vendors]&.size || 0,
        customers: parsed[:customers]&.size || 0,
        invoices: parsed[:invoices]&.size || 0,
        date_range: date_range(parsed[:transactions]),
      },
      data: parsed,
      warnings: parsed[:warnings] || [],
      ready_to_import: true
    }
  end

  # Commit the import after user reviews preview
  def commit(parsed_data, options = {})
    results = { created: {}, skipped: {}, errors: [] }

    ActiveRecord::Base.transaction do
      # 1. Import Chart of Accounts first
      if parsed_data[:chart_of_accounts]&.any?
        results[:created][:chart_of_accounts] = import_chart_of_accounts(parsed_data[:chart_of_accounts])
      end

      # 2. Import accounts
      if parsed_data[:accounts]&.any?
        results[:created][:accounts] = import_accounts(parsed_data[:accounts])
      end

      # 3. Import transactions
      if parsed_data[:transactions]&.any?
        imported = import_transactions(parsed_data[:transactions], options)
        results[:created][:transactions] = imported[:created]
        results[:skipped][:duplicates] = imported[:duplicates]
      end

      # 4. Import vendors/customers as metadata
      if parsed_data[:vendors]&.any?
        results[:created][:vendors] = parsed_data[:vendors].size
      end

      # 5. Run categorization rules
      auto_categorized = CategorizationRule.auto_categorize(@company)
      results[:auto_categorized] = auto_categorized
    end

    # Audit log
    AuditLog.record!(
      company: @company, user: @user,
      action: 'data_import',
      changes: results
    )

    results
  end

  # ============================================
  # QUICKBOOKS ONLINE
  # ============================================

  private

  def parse_qbo(content, format)
    case format
    when 'qbo_ofx'
      # QBO files are actually OFX format
      parse_ofx(content)
    else
      # QBO CSV export
      parse_qbo_csv(content)
    end
  end

  def parse_qbo_csv(content)
    rows = CSV.parse(content, headers: true, liberal_parsing: true)
    
    transactions = []
    chart_of_accounts = []
    accounts = []

    # Detect which QBO report this is
    headers = rows.headers.map(&:to_s).map(&:downcase)

    if headers.include?('transaction type') || headers.include?('type')
      # QBO Transaction Detail Report or General Ledger
      transactions = rows.map do |row|
        date_str = row['Date'] || row['Trans Date'] || row['Transaction Date']
        next unless date_str

        {
          date: (Date.parse(date_str.strip) rescue nil),
          description: row['Description'] || row['Name'] || row['Memo'] || '',
          amount: parse_amount(row['Amount'] || row['Debit'] || row['Credit']),
          category: row['Account'] || row['Category'] || row['Class'],
          type: row['Transaction Type'] || row['Type'],
          doc_num: row['Num'] || row['Doc Number'] || row['Ref No.'],
          merchant: row['Name'] || row['Payee'] || row['Vendor'],
          memo: row['Memo'] || row['Description'],
          account_name: row['Account'] || row['Bank Account'],
          split_account: row['Split'] || row['Split Account']
        }
      end.compact

    elsif headers.include?('account') && headers.include?('type')
      # QBO Chart of Accounts export
      rows.each do |row|
        chart_of_accounts << {
          name: (row['Account'] || row['Name'])&.strip,
          account_type: map_qbo_account_type(row['Type'] || row['Account Type']),
          code: row['Number'] || row['Account Number'],
          description: row['Description'] || row['Detail Type']
        }
      end
    end

    {
      transactions: transactions.select { |t| t[:date] },
      chart_of_accounts: chart_of_accounts,
      accounts: extract_accounts(transactions),
      vendors: extract_vendors(transactions),
      source: 'quickbooks_online'
    }
  end

  # ============================================
  # QUICKBOOKS DESKTOP (IIF)
  # ============================================

  def parse_qb_desktop(content, format)
    if format == 'iif'
      parse_iif(content)
    else
      parse_generic_csv(content) # Fallback for CSV exports from Desktop
    end
  end

  def parse_iif(content)
    transactions = []
    chart_of_accounts = []
    vendors = []
    customers = []

    current_trns = nil
    current_splits = []

    content.each_line do |line|
      parts = line.chomp.split("\t")
      record_type = parts[0]

      case record_type
      when 'ACCNT'
        chart_of_accounts << {
          name: parts[1]&.strip,
          account_type: map_iif_account_type(parts[2]&.strip),
          code: parts[3]&.strip,
          description: parts[4]&.strip
        }
      when 'VEND'
        vendors << { name: parts[1]&.strip, company: parts[2]&.strip }
      when 'CUST'
        customers << { name: parts[1]&.strip, company: parts[2]&.strip }
      when 'TRNS'
        # Save previous transaction
        if current_trns
          transactions << build_iif_transaction(current_trns, current_splits)
        end
        current_trns = parts
        current_splits = []
      when 'SPL'
        current_splits << parts
      when 'ENDTRNS'
        if current_trns
          transactions << build_iif_transaction(current_trns, current_splits)
        end
        current_trns = nil
        current_splits = []
      end
    end

    {
      transactions: transactions.compact,
      chart_of_accounts: chart_of_accounts,
      vendors: vendors,
      customers: customers,
      accounts: extract_accounts(transactions),
      source: 'quickbooks_desktop'
    }
  end

  def build_iif_transaction(trns_parts, splits)
    return nil if trns_parts.size < 5

    {
      date: (Date.parse(trns_parts[2]&.strip) rescue nil),
      account_name: trns_parts[1]&.strip,
      amount: trns_parts[4]&.to_f,
      merchant: trns_parts[3]&.strip,
      description: trns_parts[5]&.strip || trns_parts[3]&.strip,
      doc_num: trns_parts[6]&.strip,
      category: splits.first&.[](1)&.strip,
      type: 'check' # Default for IIF
    }
  end

  # ============================================
  # XERO
  # ============================================

  def parse_xero(content)
    rows = CSV.parse(content, headers: true, liberal_parsing: true)

    transactions = rows.map do |row|
      date_str = row['Date'] || row['*Date']
      next unless date_str

      {
        date: (Date.parse(date_str.strip) rescue nil),
        description: row['Description'] || row['*Description'] || row['Payee'] || '',
        amount: parse_amount(row['Amount'] || row['Debit Amount'] || row['Credit Amount']),
        category: row['Account'] || row['*Account'],
        merchant: row['Payee'] || row['Contact'] || row['Name'],
        memo: row['Reference'] || row['Memo'],
        account_name: row['Account'] || row['Bank Account'],
        type: row['Type'] || row['Transaction Type'],
        tax: row['Tax Rate'] || row['Tax Amount']
      }
    end.compact

    {
      transactions: transactions.select { |t| t[:date] },
      chart_of_accounts: extract_categories(transactions),
      accounts: extract_accounts(transactions),
      vendors: extract_vendors(transactions),
      source: 'xero'
    }
  end

  # ============================================
  # FRESHBOOKS
  # ============================================

  def parse_freshbooks(content)
    rows = CSV.parse(content, headers: true, liberal_parsing: true)

    transactions = rows.map do |row|
      date_str = row['Date'] || row['Date Paid'] || row['Invoice Date']
      next unless date_str

      {
        date: (Date.parse(date_str.strip) rescue nil),
        description: row['Description'] || row['Item Name'] || row['Notes'] || '',
        amount: parse_amount(row['Amount'] || row['Total'] || row['Price']),
        category: row['Category'] || row['Expense Category'],
        merchant: row['Vendor'] || row['Client'] || row['Name'],
        memo: row['Notes'],
        type: row['Type'] || 'expense'
      }
    end.compact

    {
      transactions: transactions.select { |t| t[:date] },
      chart_of_accounts: extract_categories(transactions),
      vendors: extract_vendors(transactions),
      source: 'freshbooks'
    }
  end

  # ============================================
  # WAVE
  # ============================================

  def parse_wave(content)
    rows = CSV.parse(content, headers: true, liberal_parsing: true)

    transactions = rows.map do |row|
      date_str = row['Transaction Date'] || row['Date']
      next unless date_str

      {
        date: (Date.parse(date_str.strip) rescue nil),
        description: row['Description'] || row['Vendor / Customer'] || '',
        amount: parse_amount(row['Amount (One column)'] || row['Debit'] || row['Credit']),
        category: row['Account'] || row['Category'],
        merchant: row['Vendor / Customer'],
        memo: row['Notes'],
        account_name: row['Account'],
        type: row['Transaction Type']
      }
    end.compact

    {
      transactions: transactions.select { |t| t[:date] },
      chart_of_accounts: extract_categories(transactions),
      accounts: extract_accounts(transactions),
      vendors: extract_vendors(transactions),
      source: 'wave'
    }
  end

  # ============================================
  # OFX / QFX
  # ============================================

  def parse_ofx(content)
    # Reuse existing StatementParser for OFX
    parser = StatementParser.new
    result = parser.parse(content, 'import.ofx')
    
    {
      transactions: (result[:transactions] || []).map { |t|
        {
          date: t[:date],
          description: t[:description],
          amount: t[:amount],
          merchant: t[:merchant],
          type: t[:type],
          reference: t[:reference]
        }
      },
      accounts: result[:account] ? [{ name: result[:account][:name], type: result[:account][:type] }] : [],
      source: 'ofx_qfx'
    }
  end

  # ============================================
  # GENERIC CSV (AI-assisted)
  # ============================================

  def parse_generic_csv(content)
    rows = CSV.parse(content, headers: true, liberal_parsing: true)
    headers = rows.headers

    # AI detects column mapping
    mapping = ai_detect_columns(headers, rows.first(3))

    transactions = rows.map do |row|
      {
        date: (Date.parse(row[mapping[:date]]&.strip) rescue nil),
        description: row[mapping[:description]]&.strip || '',
        amount: parse_amount(row[mapping[:amount]]),
        category: mapping[:category] ? row[mapping[:category]]&.strip : nil,
        merchant: mapping[:merchant] ? row[mapping[:merchant]]&.strip : nil,
        memo: mapping[:memo] ? row[mapping[:memo]]&.strip : nil,
        account_name: mapping[:account] ? row[mapping[:account]]&.strip : nil
      }
    end.compact

    {
      transactions: transactions.select { |t| t[:date] },
      chart_of_accounts: extract_categories(transactions),
      accounts: extract_accounts(transactions),
      vendors: extract_vendors(transactions),
      source: 'generic_csv',
      column_mapping: mapping
    }
  end

  # ============================================
  # AI ENHANCEMENT
  # ============================================

  def ai_enhance(parsed)
    return parsed if parsed[:transactions].blank?

    existing_coa = @company.chart_of_accounts.active.pluck(:name, :account_type)
    
    # Get unique categories from imported data
    import_categories = parsed[:transactions]
      .map { |t| t[:category] }
      .compact.uniq.reject(&:blank?)

    return parsed if import_categories.empty?

    prompt = <<~P
      A company is importing data into ecfoBooks. The imported data uses these categories:
      #{import_categories.join(', ')}

      Our existing Chart of Accounts:
      #{existing_coa.map { |n, t| "#{n} (#{t})" }.join(', ')}

      Map each imported category to our COA. For categories that don't map, suggest new ones.
      
      Return JSON:
      {
        "category_map": {
          "imported_name": "our_category_name"
        },
        "new_categories": [
          {"name": "New Category", "account_type": "expense", "source": "original imported name"}
        ]
      }
    P

    response = call_ai(prompt)
    begin
      mapping = JSON.parse(response)
      parsed[:category_mapping] = mapping['category_map'] || {}
      parsed[:suggested_new_categories] = mapping['new_categories'] || []
      
      # Apply mapping to transactions
      parsed[:transactions].each do |txn|
        next unless txn[:category]
        mapped = parsed[:category_mapping][txn[:category]]
        txn[:mapped_category] = mapped if mapped
      end
    rescue
      # AI failed, continue without enhancement
    end

    parsed
  end

  # ============================================
  # COMMIT HELPERS
  # ============================================

  def import_chart_of_accounts(coa_entries)
    created = 0
    coa_entries.each do |entry|
      next if entry[:name].blank?
      code = ChartOfAccountTemplates.next_code(@company, entry[:account_type] || 'expense')
      @company.chart_of_accounts.find_or_create_by!(name: entry[:name]) do |coa|
        coa.account_type = entry[:account_type] || 'expense'
        coa.code = entry[:code] || code
        coa.active = true
      end
      created += 1
    end
    created
  end

  def import_accounts(account_entries)
    created = 0
    account_entries.each do |entry|
      next if entry[:name].blank?
      @company.accounts.find_or_create_by!(name: entry[:name]) do |acct|
        acct.account_type = entry[:type] || 'checking'
        acct.institution = entry[:institution]
      end
      created += 1
    end
    created
  end

  def import_transactions(txn_entries, options = {})
    created = 0
    duplicates = 0

    txn_entries.each do |entry|
      next unless entry[:date]

      # Duplicate check
      existing = @company.account_transactions.where(
        date: entry[:date],
        amount: entry[:amount],
        description: entry[:description]
      ).exists?

      if existing
        duplicates += 1
        next
      end

      # Find or resolve account
      account = nil
      if entry[:account_name]
        account = @company.accounts.find_by('LOWER(name) LIKE ?', "%#{entry[:account_name].downcase}%")
      end
      account ||= @company.accounts.first

      # Find category
      coa = nil
      category_name = entry[:mapped_category] || entry[:category]
      if category_name
        coa = @company.chart_of_accounts.find_by('LOWER(name) LIKE ?', "%#{category_name.downcase}%")
      end

      txn = @company.account_transactions.create!(
        account: account,
        chart_of_account: coa,
        date: entry[:date],
        description: entry[:description] || entry[:merchant] || '',
        amount: entry[:amount] || 0,
        merchant_name: entry[:merchant],
        transaction_type: entry[:type] || 'debit',
        reference_number: entry[:doc_num] || entry[:reference]
      )

      # Journal entry is created automatically via AccountTransaction's
      # after_save :sync_journal_entry callback when chart_of_account_id is set

      created += 1
    end

    { created: created, duplicates: duplicates }
  end

  # ============================================
  # DETECTION HELPERS
  # ============================================

  def detect_csv_format(content)
    first_lines = content.lines.first(5).join
    headers = CSV.parse_line(content.lines.first) rescue []
    headers_lower = headers.map { |h| h&.downcase&.strip }

    # QuickBooks Online patterns
    if headers_lower.include?('transaction type') || first_lines.include?('QuickBooks')
      return { source: 'quickbooks_online', format: 'csv', confidence: 90 }
    end

    # Xero patterns
    if headers_lower.include?('*date') || headers_lower.include?('*amount') || first_lines.include?('Xero')
      return { source: 'xero', format: 'csv', confidence: 90 }
    end

    # FreshBooks patterns
    if headers_lower.include?('expense category') || headers_lower.include?('item name')
      return { source: 'freshbooks', format: 'csv', confidence: 85 }
    end

    # Wave patterns
    if headers_lower.include?('amount (one column)') || headers_lower.include?('vendor / customer')
      return { source: 'wave', format: 'csv', confidence: 85 }
    end

    { source: 'generic_csv', format: 'csv', confidence: 50 }
  end

  def detect_json_format(content)
    data = JSON.parse(content) rescue nil
    return { source: 'generic_csv', format: 'json', confidence: 30 } unless data

    if data.is_a?(Hash) && (data['QueryResponse'] || data['Account'])
      { source: 'quickbooks_online', format: 'json_api', confidence: 95 }
    else
      { source: 'generic_csv', format: 'json', confidence: 40 }
    end
  end

  def detect_csv_source(content)
    detect_csv_format(content)[:source]
  end

  def ai_detect_columns(headers, sample_rows)
    # Quick pattern match first
    mapping = {}
    headers.each do |h|
      hl = h&.downcase&.strip
      case hl
      when /date/ then mapping[:date] ||= h
      when /desc|memo|detail|narrative|particular/ then mapping[:description] ||= h
      when /amount|sum|value|total/ then mapping[:amount] ||= h
      when /category|account|class|type/ then mapping[:category] ||= h
      when /vendor|merchant|payee|name/ then mapping[:merchant] ||= h
      when /memo|note|reference/ then mapping[:memo] ||= h
      when /debit/ then mapping[:debit] ||= h
      when /credit/ then mapping[:credit] ||= h
      end
    end

    # Handle debit/credit columns → single amount
    if !mapping[:amount] && (mapping[:debit] || mapping[:credit])
      mapping[:amount] = mapping[:debit] || mapping[:credit]
    end

    # If we couldn't figure it out, ask AI
    if mapping[:date].nil? || mapping[:amount].nil?
      ai_mapping = ai_column_detect(headers, sample_rows)
      mapping.merge!(ai_mapping) { |_k, old, _new| old } # Keep existing, fill gaps
    end

    mapping
  end

  def ai_column_detect(headers, sample_rows)
    prompt = <<~P
      CSV file with headers: #{headers.join(', ')}
      Sample rows: #{sample_rows.map { |r| r.to_h.values.join(', ') }.join("\n")}
      
      Map these columns. Return JSON: {"date": "column_name", "description": "column_name", "amount": "column_name", "category": "column_name_or_null", "merchant": "column_name_or_null"}
    P

    response = call_ai(prompt)
    result = JSON.parse(response) rescue {}
    result.transform_keys(&:to_sym)
  end

  # ============================================
  # UTILITY
  # ============================================

  def parse_amount(str)
    return 0.0 unless str
    str.to_s.gsub(/[^0-9.\-\(\)]/, '').gsub(/\((.+)\)/, '-\1').to_f
  end

  def extract_accounts(transactions)
    transactions
      .map { |t| t[:account_name] }
      .compact.uniq.reject(&:blank?)
      .map { |name| { name: name, type: guess_account_type(name) } }
  end

  def extract_vendors(transactions)
    transactions
      .map { |t| t[:merchant] }
      .compact.uniq.reject(&:blank?)
      .map { |name| { name: name } }
  end

  def extract_categories(transactions)
    transactions
      .map { |t| t[:category] }
      .compact.uniq.reject(&:blank?)
      .map { |name| { name: name, account_type: 'expense' } }
  end

  def date_range(transactions)
    return nil unless transactions&.any?
    dates = transactions.map { |t| t[:date] }.compact
    return nil if dates.empty?
    { from: dates.min, to: dates.max }
  end

  def guess_account_type(name)
    case name&.downcase
    when /check|saving|bank|cash/ then 'checking'
    when /credit|visa|master|amex|card/ then 'credit_card'
    when /loan|mortgage|line of credit/ then 'loan'
    when /invest|brokerage|401k|ira/ then 'investment'
    else 'checking'
    end
  end

  def map_qbo_account_type(qbo_type)
    return 'expense' unless qbo_type
    case qbo_type.downcase
    when /income|revenue|sales/ then 'income'
    when /expense|cost of goods/ then 'expense'
    when /bank|cash|current asset|fixed asset|other asset|accounts receivable/ then 'asset'
    when /credit card|current liab|long term|other liab|accounts payable/ then 'liability'
    when /equity|retained|owner/ then 'equity'
    else 'expense'
    end
  end

  def map_iif_account_type(iif_type)
    return 'expense' unless iif_type
    case iif_type
    when 'BANK' then 'asset'
    when 'CCARD' then 'liability'
    when 'INC' then 'income'
    when 'EXP' then 'expense'
    when 'FIXASSET' then 'asset'
    when 'OASSET' then 'asset'
    when 'OCLIAB' then 'liability'
    when 'LTLIAB' then 'liability'
    when 'EQUITY' then 'equity'
    when 'AP' then 'liability'
    when 'AR' then 'asset'
    when 'COGS' then 'expense'
    else 'expense'
    end
  end

  def call_ai(prompt)
    api_key = Rails.application.credentials.dig(:openai, :api_key) || ENV['OPENAI_API_KEY']
    return '{}' unless api_key

    uri = URI('https://api.openai.com/v1/chat/completions')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    body = {
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: 'You are a bookkeeping data migration expert. Return ONLY valid JSON.' },
        { role: 'user', content: prompt }
      ],
      temperature: 0.1,
      max_tokens: 3000,
      response_format: { type: 'json_object' }
    }

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'
    request.body = body.to_json

    response = http.request(request)
    JSON.parse(response.body).dig('choices', 0, 'message', 'content') || '{}'
  rescue => e
    Rails.logger.error "DataImporter AI error: #{e.message}"
    '{}'
  end
end
