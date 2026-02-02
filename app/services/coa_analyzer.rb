require 'net/http'
require 'json'
require 'csv'

class CoaAnalyzer
  def initialize(company)
    @company = company
  end

  # ============================================
  # ANALYZE TRANSACTIONS → SUGGEST NEW CATEGORIES
  # ============================================

  # Look at uncategorized transactions and suggest new COA entries
  def suggest_from_transactions
    uncategorized = @company.account_transactions.where(chart_of_account_id: nil)
      .where.not(merchant_name: [nil, ''])
      .group(:merchant_name)
      .select('merchant_name, COUNT(*) as cnt, SUM(amount) as total')
      .order('cnt DESC')
      .limit(50)

    existing = @company.chart_of_accounts.active.pluck(:name, :account_type)

    prompt = <<~P
      I have a company with these existing Chart of Accounts categories:
      #{existing.map { |n, t| "#{n} (#{t})" }.join(', ')}

      These are the top uncategorized merchants/vendors:
      #{uncategorized.map { |u| "#{u.merchant_name}: #{u.cnt} transactions, $#{'%.2f' % u.total.abs} total" }.join("\n")}

      Analyze these merchants and:
      1. Map each merchant to an EXISTING category if possible
      2. If no existing category fits well, suggest a NEW category to create

      Return JSON:
      {
        "mappings": [
          {"merchant": "name", "existing_category": "category name", "confidence": 90}
        ],
        "new_categories": [
          {"name": "Suggested Category Name", "account_type": "expense", "reason": "why this is needed", "merchants": ["merchant1", "merchant2"]}
        ]
      }
    P

    response = call_ai(prompt)
    begin
      JSON.parse(response)
    rescue
      { "mappings" => [], "new_categories" => [] }
    end
  end

  # ============================================
  # IMPORT FROM QUICKBOOKS
  # ============================================

  # Parse a QuickBooks chart of accounts export (CSV or IIF)
  def import_quickbooks_coa(content, filename)
    if filename.end_with?('.iif')
      parse_qb_iif(content)
    else
      parse_qb_csv(content)
    end
  end

  # Parse QuickBooks transaction export and build COA from it
  def import_quickbooks_data(content, filename)
    # Parse the transactions
    transactions = parse_qb_transactions(content)
    
    # Extract unique categories used
    categories = transactions.map { |t| t['category'] || t['account'] }.compact.uniq

    # Ask AI to map QB categories to our standard COA + suggest new ones
    existing = @company.chart_of_accounts.active.pluck(:name, :account_type)

    prompt = <<~P
      A company is migrating from QuickBooks. Their QuickBooks used these categories:
      #{categories.join(', ')}

      Our current Chart of Accounts has:
      #{existing.map { |n, t| "#{n} (#{t})" }.join(', ')}

      Create a mapping plan:
      1. Map each QB category to the closest existing category (if good match)
      2. For QB categories that don't map well, suggest creating new categories
      3. Maintain consistency with how the company categorized things in QB

      Return JSON:
      {
        "mappings": [
          {"qb_category": "QuickBooks name", "our_category": "our category name", "action": "map_existing"}
        ],
        "new_categories": [
          {"name": "New Category", "account_type": "expense|income|asset|liability|equity", "qb_source": "original QB name", "reason": "why"}
        ],
        "notes": "any migration observations"
      }
    P

    response = call_ai(prompt)
    begin
      result = JSON.parse(response)
      result['transactions'] = transactions
      result
    rescue
      { 'mappings' => [], 'new_categories' => [], 'transactions' => transactions }
    end
  end

  # Apply the migration plan — create new categories and map transactions
  def apply_migration(plan)
    created = 0
    mapped = 0

    # Create new categories
    (plan['new_categories'] || []).each do |cat|
      code = ChartOfAccountTemplates.next_code(@company, cat['account_type'])
      @company.chart_of_accounts.find_or_create_by!(name: cat['name']) do |coa|
        coa.account_type = cat['account_type']
        coa.code = code
        coa.active = true
      end
      created += 1
    end

    # Create categorization rules from mappings
    (plan['mappings'] || []).each do |mapping|
      target = mapping['our_category'] || mapping['existing_category']
      source = mapping['qb_category'] || mapping['merchant']
      next unless target && source

      coa = @company.chart_of_accounts.find_by('LOWER(name) = ?', target.downcase) ||
            @company.chart_of_accounts.find_by('LOWER(name) LIKE ?', "%#{target.downcase}%")
      next unless coa

      @company.categorization_rules.find_or_create_by!(
        match_field: 'description',
        match_type: 'contains',
        match_value: source.downcase
      ) do |rule|
        rule.chart_of_account = coa
        rule.priority = 5
      end
      mapped += 1
    end

    # Run rules on existing uncategorized
    auto_categorized = CategorizationRule.auto_categorize(@company)

    { created_categories: created, created_rules: mapped, auto_categorized: auto_categorized }
  end

  # ============================================
  # ONGOING COA EVOLUTION
  # ============================================

  # Periodically analyze if the COA needs updates
  def health_check
    issues = []

    # Check for Miscellaneous overuse
    misc = @company.chart_of_accounts.find_by('LOWER(name) LIKE ?', '%miscellaneous%')
    if misc
      misc_count = misc.account_transactions.where(date: 90.days.ago..Date.current).count
      total_count = @company.account_transactions.where(date: 90.days.ago..Date.current).count
      if total_count > 0 && (misc_count.to_f / total_count) > 0.15
        issues << {
          type: 'misc_overuse',
          message: "#{((misc_count.to_f / total_count) * 100).round(0)}% of transactions are in 'Miscellaneous' — consider creating more specific categories",
          count: misc_count
        }
      end
    end

    # Check for categories with 0 transactions (stale)
    stale = @company.chart_of_accounts.active.select { |coa|
      coa.account_transactions.where(date: 365.days.ago..Date.current).count == 0
    }
    if stale.size > 5
      issues << {
        type: 'stale_categories',
        message: "#{stale.size} categories have no transactions in the past year. Consider deactivating: #{stale.first(5).map(&:name).join(', ')}",
        categories: stale.map(&:name)
      }
    end

    # Check for uncategorized pile-up
    uncategorized = @company.account_transactions.where(chart_of_account_id: nil).count
    total = @company.account_transactions.count
    if total > 0 && uncategorized > 0
      pct = (uncategorized.to_f / total * 100).round(0)
      if pct > 20
        issues << {
          type: 'uncategorized_pileup',
          message: "#{pct}% of transactions (#{uncategorized}) are uncategorized. Want me to suggest categories?",
          count: uncategorized
        }
      end
    end

    # Suggest new categories based on transaction patterns
    if uncategorized > 10
      suggestions = suggest_from_transactions
      if suggestions['new_categories']&.any?
        issues << {
          type: 'suggested_categories',
          message: "Based on your transactions, I'd suggest adding: #{suggestions['new_categories'].map { |c| c['name'] }.join(', ')}",
          suggestions: suggestions['new_categories']
        }
      end
    end

    issues
  end

  private

  def parse_qb_csv(content)
    parsed = CSV.parse(content, headers: true, liberal_parsing: true)
    
    parsed.map do |row|
      name = row['Account'] || row['Name'] || row['account_name']
      type = row['Type'] || row['Account Type'] || row['type']
      next unless name

      mapped_type = map_qb_type(type)
      {
        'name' => name.strip,
        'account_type' => mapped_type,
        'qb_type' => type,
        'code' => row['Number'] || row['Code']
      }
    end.compact
  end

  def parse_qb_iif(content)
    accounts = []
    content.each_line do |line|
      next unless line.start_with?('ACCNT')
      parts = line.split("\t")
      next if parts.size < 3

      accounts << {
        'name' => parts[1]&.strip,
        'account_type' => map_qb_type(parts[2]&.strip),
        'qb_type' => parts[2]&.strip
      }
    end
    accounts
  end

  def parse_qb_transactions(content)
    begin
      parsed = CSV.parse(content, headers: true, liberal_parsing: true)
      parsed.map do |row|
        date = row['Date'] || row['Trans Date'] || row['date']
        desc = row['Description'] || row['Name'] || row['Memo'] || row['Payee']
        amount = row['Amount'] || row['Debit'] || row['Credit']
        category = row['Account'] || row['Category'] || row['Class']

        next unless date && desc
        {
          'date' => (Date.parse(date.strip) rescue nil)&.to_s,
          'description' => desc.strip,
          'amount' => amount.to_s.gsub(/[^0-9.\-]/, '').to_f,
          'category' => category&.strip
        }
      end.compact
    rescue
      []
    end
  end

  def map_qb_type(qb_type)
    return 'expense' unless qb_type
    case qb_type.downcase
    when /income|revenue|sales/ then 'income'
    when /expense|cost/ then 'expense'
    when /bank|cash|current asset|fixed asset|other asset|receivable/ then 'asset'
    when /credit card|current liab|long term|other liab|payable/ then 'liability'
    when /equity|retained|owner/ then 'equity'
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
        { role: 'system', content: 'You are a bookkeeping expert. Help build and maintain Chart of Accounts. Return ONLY valid JSON.' },
        { role: 'user', content: prompt }
      ],
      temperature: 0.2,
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
    Rails.logger.error "CoaAnalyzer AI error: #{e.message}"
    '{}'
  end
end
