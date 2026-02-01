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
      next if account.transactions.exists?(
        date: txn_data['date'],
        amount: txn_data['amount'],
        description: txn_data['description']
      )

      txn = account.transactions.create!(
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
    # Convert PDF to text (requires pdftotext or similar)
    text = extract_pdf_text(content)
    return { success: false, error: 'Could not extract text from PDF' } if text.blank?

    ai_parse_statement(text, filename)
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
