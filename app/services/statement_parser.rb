require 'csv'
require 'net/http'
require 'json'

class StatementParser
  def initialize(company)
    @company = company
  end

  # Main entry: parse any file type and return normalized transactions
  def parse(file_content, filename, file_type = nil)
    file_type ||= detect_type(filename)

    case file_type
    when 'csv'
      parse_csv(file_content)
    when 'ofx', 'qfx'
      parse_ofx(file_content)
    when 'pdf'
      parse_pdf_with_ai(file_content, filename)
    else
      parse_with_ai(file_content, filename)
    end
  end

  # Import parsed transactions into the database
  def import(upload, account)
    transactions = upload.parsed_transactions
    imported = 0
    categorized = 0

    transactions.each do |txn_data|
      # Skip duplicates (same date + amount + description)
      next if account.account_transactions.exists?(
        date: txn_data['date'],
        amount: txn_data['amount'],
        description: txn_data['description']
      )

      txn = account.account_transactions.create!(
        date: txn_data['date'],
        description: txn_data['description'],
        amount: txn_data['amount'],
        merchant_name: txn_data['merchant'] || txn_data['description'],
        pending: false,
        category: txn_data['suggested_category']
      )

      imported += 1

      # Auto-categorize if AI suggested a category
      if txn_data['suggested_category']
        coa = @company.chart_of_accounts.find_by('LOWER(name) LIKE ?', "%#{txn_data['suggested_category'].downcase}%")
        if coa
          txn.update!(chart_of_account_id: coa.id)
          categorized += 1
        end
      end
    end

    # Run categorization rules on remaining uncategorized
    rules_categorized = CategorizationRule.auto_categorize(@company)
    categorized += rules_categorized

    upload.update!(
      status: 'imported',
      account: account,
      transactions_imported: imported,
      transactions_categorized: categorized
    )

    { imported: imported, categorized: categorized, skipped_duplicates: transactions.size - imported }
  end

  private

  def detect_type(filename)
    ext = File.extname(filename).downcase.delete('.')
    case ext
    when 'csv', 'tsv' then 'csv'
    when 'ofx', 'qfx' then 'ofx'
    when 'pdf' then 'pdf'
    else 'unknown'
    end
  end

  # ============================================
  # CSV PARSING — handles any bank's CSV format
  # ============================================

  def parse_csv(content)
    # First, try to detect the format automatically
    lines = content.lines
    return ai_parse_csv(content) if lines.size < 2

    # Try standard CSV parsing
    begin
      parsed = CSV.parse(content, headers: true, liberal_parsing: true)
      headers = parsed.headers.compact.map(&:strip)

      # Detect column mapping via AI if headers don't match common patterns
      mapping = detect_csv_mapping(headers, parsed.first(3))

      if mapping
        transactions = parsed.map do |row|
          date = parse_date(row[mapping['date']])
          next unless date

          amount = parse_amount(row[mapping['amount']], row[mapping['debit']], row[mapping['credit']])
          description = row[mapping['description']]&.strip
          next if description.blank?

          {
            'date' => date.to_s,
            'description' => description,
            'amount' => amount,
            'merchant' => description,
            'original_row' => row.to_h
          }
        end.compact

        # Ask AI to suggest categories for all transactions
        transactions = ai_categorize_batch(transactions) if transactions.any?

        { success: true, transactions: transactions, format: 'csv', count: transactions.size }
      else
        # Can't auto-detect, use AI
        ai_parse_csv(content)
      end
    rescue CSV::MalformedCSVError
      ai_parse_csv(content)
    end
  end

  def detect_csv_mapping(headers, sample_rows)
    # Common header patterns
    date_patterns = /date|posted|trans.*date|effective/i
    desc_patterns = /desc|description|memo|narrative|detail|payee|name/i
    amount_patterns = /amount|sum|value/i
    debit_patterns = /debit|withdrawal|charge/i
    credit_patterns = /credit|deposit|payment/i

    mapping = {}
    headers.each do |h|
      mapping['date'] = h if h.match?(date_patterns) && !mapping['date']
      mapping['description'] = h if h.match?(desc_patterns) && !mapping['description']
      mapping['amount'] = h if h.match?(amount_patterns) && !mapping['amount']
      mapping['debit'] = h if h.match?(debit_patterns)
      mapping['credit'] = h if h.match?(credit_patterns)
    end

    # Need at least date and description
    return nil unless mapping['date'] && mapping['description']
    # Need amount OR debit/credit
    return nil unless mapping['amount'] || mapping['debit'] || mapping['credit']

    mapping
  end

  def parse_date(value)
    return nil if value.blank?
    Date.parse(value.strip)
  rescue
    nil
  end

  def parse_amount(amount, debit, credit)
    if amount.present?
      clean = amount.to_s.gsub(/[^0-9.\-]/, '')
      clean.to_f
    elsif debit.present? || credit.present?
      d = debit.to_s.gsub(/[^0-9.]/, '').to_f
      c = credit.to_s.gsub(/[^0-9.]/, '').to_f
      c > 0 ? c : -d
    else
      0
    end
  end

  # ============================================
  # OFX/QFX PARSING — standard banking format
  # ============================================

  def parse_ofx(content)
    transactions = []

    # Simple OFX parser (doesn't need a gem)
    content.scan(/<STMTTRN>(.*?)<\/STMTTRN>/m).each do |match|
      block = match[0]
      
      date_match = block.match(/<DTPOSTED>(\d{8})/)
      amount_match = block.match(/<TRNAMT>([\-\d.]+)/)
      name_match = block.match(/<NAME>(.+?)[\n<]/)
      memo_match = block.match(/<MEMO>(.+?)[\n<]/)
      id_match = block.match(/<FITID>(.+?)[\n<]/)

      next unless date_match && amount_match

      date = Date.strptime(date_match[1], '%Y%m%d') rescue nil
      next unless date

      transactions << {
        'date' => date.to_s,
        'description' => (name_match ? name_match[1].strip : memo_match ? memo_match[1].strip : 'Unknown'),
        'amount' => amount_match[1].to_f,
        'merchant' => name_match ? name_match[1].strip : nil,
        'bank_id' => id_match ? id_match[1].strip : nil
      }
    end

    # AI categorize
    transactions = ai_categorize_batch(transactions) if transactions.any?

    { success: true, transactions: transactions, format: 'ofx', count: transactions.size }
  end

  # ============================================
  # PDF PARSING — AI extracts from statement
  # ============================================

  def parse_pdf_with_ai(content, filename)
    # Chain: Kimi K2.5 (default) → Claude (native PDF) → OpenAI+pdftotext (fallback)

    # 1. Try Kimi K2.5 via OpenRouter
    if openrouter_api_key.present?
      result = parse_pdf_with_kimi(content, filename)
      return result if result[:success]
      Rails.logger.warn "StatementParser: Kimi PDF parsing failed, trying Claude"
    end

    # 2. Try Claude (native PDF reading, no pdftotext needed)
    if anthropic_api_key.present?
      result = parse_pdf_with_claude(content, filename)
      return result if result[:success]
      Rails.logger.warn "StatementParser: Claude PDF parsing failed, falling back to OpenAI+pdftotext"
    end

    # 3. Fallback: extract text with pdftotext, then use OpenAI
    text = extract_pdf_text(content)
    return { success: false, error: 'Could not extract text from PDF. Configure OPENROUTER_API_KEY, ANTHROPIC_API_KEY, or OPENAI_API_KEY.' } if text.blank?

    ai_parse_statement(text, filename)
  end

  # Parse PDF with Kimi K2.5 via OpenRouter (uses pdftotext for text extraction)
  def parse_pdf_with_kimi(content, filename)
    text = extract_pdf_text(content)
    return { success: false, error: 'Could not extract text from PDF for Kimi' } if text.blank?

    # Truncate to fit in context
    text = text[0..30000] if text.length > 30000

    categories = @company.chart_of_accounts.active.pluck(:name, :account_type)
      .map { |n, t| "#{n} (#{t})" }.join(', ')

    prompt = <<~P
      Parse this bank/credit card statement and extract ALL transactions.
      For each transaction, suggest the best category from the available list.

      Available categories: #{categories}

      Statement content (#{filename}):
      ```
      #{text}
      ```

      Return a JSON object:
      {
        "account_name": "detected account name or null",
        "account_type": "checking/savings/credit_card/etc",
        "statement_period": "detected date range",
        "statement_ending_balance": 12345.67,
        "transactions": [
          {
            "date": "YYYY-MM-DD",
            "description": "transaction description",
            "amount": -123.45,
            "merchant": "merchant name if identifiable",
            "suggested_category": "best matching category name or null"
          }
        ],
        "notes": "any parsing observations"
      }

      Rules:
      - Negative amounts = money out (expenses, payments)
      - Positive amounts = money in (deposits, refunds)
      - Dates must be YYYY-MM-DD format
      - Include ALL transactions, don't skip any
      - statement_ending_balance is the ending/closing balance shown on the statement
      - If you can't determine date format, note it
      - Return ONLY valid JSON, no other text
    P

    uri = URI('https://openrouter.ai/api/v1/chat/completions')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 120

    body = {
      model: 'moonshotai/kimi-k2.5',
      messages: [
        { role: 'system', content: 'You are a financial document parser. Extract transactions accurately. Return ONLY valid JSON.' },
        { role: 'user', content: prompt }
      ],
      temperature: 0.1,
      max_tokens: 8000
    }

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{openrouter_api_key}"
    request['Content-Type'] = 'application/json'
    request['HTTP-Referer'] = 'https://myecfo.com'
    request['X-Title'] = 'MYeCFO Statement Parser'
    request.body = body.to_json

    response = http.request(request)
    response_body = JSON.parse(response.body)

    raw_text = response_body.dig('choices', 0, 'message', 'content') || ''
    # Extract JSON from response (model may wrap in markdown code blocks)
    json_str = raw_text[/\{.*\}/m] || '{}'
    result = JSON.parse(json_str)

    transactions = result['transactions'] || []
    {
      success: true,
      transactions: transactions,
      account_name: result['account_name'],
      account_type: result['account_type'],
      statement_period: result['statement_period'],
      statement_ending_balance: result['statement_ending_balance']&.to_f,
      notes: result['notes'],
      format: 'kimi_pdf',
      count: transactions.size,
      parser_engine: 'kimi'
    }
  rescue => e
    Rails.logger.error "StatementParser Kimi PDF error: #{e.message}"
    { success: false, error: "Kimi PDF parsing failed: #{e.message}" }
  end

  # Parse PDF natively with Claude API (no pdftotext needed)
  def parse_pdf_with_claude(content, filename)
    categories = @company.chart_of_accounts.active.pluck(:name, :account_type)
      .map { |n, t| "#{n} (#{t})" }.join(', ')

    pdf_base64 = Base64.strict_encode64(content)

    prompt = <<~P
      Parse this bank/credit card statement PDF and extract ALL transactions.
      For each transaction, suggest the best category from the available list.

      Available categories: #{categories}

      Return a JSON object:
      {
        "account_name": "detected account name or null",
        "account_type": "checking/savings/credit_card/etc",
        "statement_period": "detected date range",
        "statement_ending_balance": 12345.67,
        "transactions": [
          {
            "date": "YYYY-MM-DD",
            "description": "transaction description",
            "amount": -123.45,
            "merchant": "merchant name if identifiable",
            "suggested_category": "best matching category name or null"
          }
        ],
        "notes": "any parsing observations"
      }

      Rules:
      - Negative amounts = money out (expenses, payments)
      - Positive amounts = money in (deposits, refunds)
      - Dates must be YYYY-MM-DD format
      - Include ALL transactions, don't skip any
      - statement_ending_balance is the ending/closing balance shown on the statement
      - If you can't determine date format, note it
    P

    uri = URI('https://api.anthropic.com/v1/messages')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 120

    body = {
      model: 'claude-sonnet-4-20250514',
      max_tokens: 8000,
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'document',
              source: {
                type: 'base64',
                media_type: 'application/pdf',
                data: pdf_base64
              }
            },
            {
              type: 'text',
              text: prompt
            }
          ]
        }
      ]
    }

    request = Net::HTTP::Post.new(uri)
    request['x-api-key'] = anthropic_api_key
    request['anthropic-version'] = '2023-06-01'
    request['content-type'] = 'application/json'
    request.body = body.to_json

    response = http.request(request)
    response_body = JSON.parse(response.body)

    raw_text = response_body.dig('content', 0, 'text') || ''
    # Extract JSON from response (Claude may wrap in markdown code blocks)
    json_str = raw_text[/\{.*\}/m] || '{}'
    result = JSON.parse(json_str)

    transactions = result['transactions'] || []
    {
      success: true,
      transactions: transactions,
      account_name: result['account_name'],
      account_type: result['account_type'],
      statement_period: result['statement_period'],
      statement_ending_balance: result['statement_ending_balance']&.to_f,
      notes: result['notes'],
      format: 'claude_pdf',
      count: transactions.size,
      parser_engine: 'claude'
    }
  rescue => e
    Rails.logger.error "StatementParser Claude PDF error: #{e.message}"
    { success: false, error: "Claude PDF parsing failed: #{e.message}" }
  end

  def extract_pdf_text(content)
    # Write to temp file and extract with pdftotext
    require 'tempfile'
    tmp = Tempfile.new(['statement', '.pdf'])
    tmp.binmode
    tmp.write(content)
    tmp.close

    text = `pdftotext -layout "#{tmp.path}" - 2>/dev/null`
    tmp.unlink
    text.presence
  rescue
    nil
  end

  def anthropic_api_key
    Rails.application.credentials.dig(:anthropic, :api_key) || ENV['ANTHROPIC_API_KEY']
  end

  def openrouter_api_key
    Rails.application.credentials.dig(:openrouter, :api_key) || ENV['OPENROUTER_API_KEY']
  end

  # ============================================
  # AI-POWERED PARSING — handles anything
  # ============================================

  def ai_parse_csv(content)
    ai_parse_statement(content, 'statement.csv')
  end

  def ai_parse_statement(text, filename)
    # Truncate to fit in context
    text = text[0..15000] if text.length > 15000

    categories = @company.chart_of_accounts.active.pluck(:name, :account_type)
      .map { |n, t| "#{n} (#{t})" }.join(', ')

    prompt = <<~P
      Parse this bank/credit card statement and extract ALL transactions.
      For each transaction, also suggest the best category from the available list.

      Available categories: #{categories}

      Statement content (#{filename}):
      ```
      #{text}
      ```

      Return a JSON object:
      {
        "account_name": "detected account name or null",
        "account_type": "checking/savings/credit_card/etc",
        "statement_period": "detected date range",
        "transactions": [
          {
            "date": "YYYY-MM-DD",
            "description": "transaction description",
            "amount": -123.45,
            "merchant": "merchant name if identifiable",
            "suggested_category": "best matching category name or null"
          }
        ],
        "notes": "any parsing observations"
      }

      Rules:
      - Negative amounts = money out (expenses, payments)
      - Positive amounts = money in (deposits, refunds)
      - Dates must be YYYY-MM-DD format
      - Include ALL transactions, don't skip any
      - If you can't determine date format, note it
    P

    response = call_ai(prompt)
    begin
      result = JSON.parse(response)
      transactions = result['transactions'] || []
      {
        success: true,
        transactions: transactions,
        account_name: result['account_name'],
        account_type: result['account_type'],
        statement_period: result['statement_period'],
        notes: result['notes'],
        format: 'ai_parsed',
        count: transactions.size
      }
    rescue
      { success: false, error: 'AI could not parse the statement', raw: response }
    end
  end

  # Batch categorize transactions using AI
  def ai_categorize_batch(transactions)
    categories = @company.chart_of_accounts.active.pluck(:name, :account_type)
      .map { |n, t| "#{n} (#{t})" }.join(', ')

    txn_list = transactions.map { |t| "#{t['date']} | #{t['description']} | $#{t['amount']}" }.join("\n")

    prompt = <<~P
      Categorize these transactions. Available categories: #{categories}

      Transactions:
      #{txn_list}

      Return JSON array with suggested_category for each (same order):
      [{"suggested_category": "category name or null"}, ...]
    P

    response = call_ai(prompt)
    begin
      suggestions = JSON.parse(response)
      transactions.each_with_index do |txn, i|
        txn['suggested_category'] = suggestions[i]&.dig('suggested_category') if suggestions[i]
      end
    rescue
      # Leave without categories if AI fails
    end

    transactions
  end

  def call_ai(prompt)
    api_key = Rails.application.credentials.dig(:openai, :api_key) || ENV['OPENAI_API_KEY']
    return '{"error": "AI not configured"}' unless api_key

    uri = URI('https://api.openai.com/v1/chat/completions')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 60  # Longer timeout for parsing

    body = {
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: 'You are a financial document parser. Extract transactions accurately. Return ONLY valid JSON.' },
        { role: 'user', content: prompt }
      ],
      temperature: 0.1,
      max_tokens: 4000,
      response_format: { type: 'json_object' }
    }

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'
    request.body = body.to_json

    response = http.request(request)
    JSON.parse(response.body).dig('choices', 0, 'message', 'content') || '{}'
  rescue => e
    Rails.logger.error "StatementParser AI error: #{e.message}"
    '{}'
  end
end
