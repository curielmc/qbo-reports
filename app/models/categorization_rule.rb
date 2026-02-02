class CategorizationRule < ApplicationRecord
  belongs_to :company
  belongs_to :chart_of_account

  validates :match_type, presence: true, inclusion: { in: %w[contains exact starts_with regex] }
  validates :match_field, presence: true, inclusion: { in: %w[description merchant_name category] }
  validates :match_value, presence: true

  scope :active, -> { where(active: true) }
  scope :by_priority, -> { order(priority: :desc) }

  # Check if a transaction matches this rule
  def matches?(transaction)
    field_value = transaction.send(match_field).to_s.downcase
    pattern = match_value.downcase

    case match_type
    when 'contains'
      field_value.include?(pattern)
    when 'exact'
      field_value == pattern
    when 'starts_with'
      field_value.start_with?(pattern)
    when 'regex'
      field_value.match?(Regexp.new(pattern, Regexp::IGNORECASE))
    else
      false
    end
  rescue
    false
  end

  # Apply rules to uncategorized transactions for a company
  def self.auto_categorize(company)
    rules = company.categorization_rules.active.by_priority
    return 0 if rules.empty?

    uncategorized = company.account_transactions.where(chart_of_account_id: nil)
    categorized_count = 0

    uncategorized.find_each do |transaction|
      rules.each do |rule|
        if rule.matches?(transaction)
          transaction.update!(chart_of_account_id: rule.chart_of_account_id)
          rule.increment!(:times_applied)
          categorized_count += 1
          break # First matching rule wins
        end
      end
    end

    categorized_count
  end

  # Learn from manual categorizations — suggest new rules
  def self.suggest_rules(company)
    # Find patterns in manually categorized transactions
    suggestions = []

    company.chart_of_accounts.active.each do |coa|
      transactions = coa.account_transactions.where.not(merchant_name: [nil, ''])
      
      # Group by merchant name and find common ones
      merchant_counts = transactions.group(:merchant_name).count
      merchant_counts.each do |merchant, count|
        next if count < 3 # Need at least 3 occurrences
        next if company.categorization_rules.exists?(match_field: 'merchant_name', match_value: merchant.downcase)
        
        suggestions << {
          match_field: 'merchant_name',
          match_type: 'exact',
          match_value: merchant,
          chart_of_account_id: coa.id,
          chart_of_account_name: coa.name,
          confidence: [count * 10, 100].min,
          occurrences: count
        }
      end
    end

    suggestions.sort_by { |s| -s[:confidence] }.first(20)
  end

  # AI-powered rule suggestions using OpenAI
  def self.ai_suggest_rules(company)
    # Gather uncategorized transaction samples
    uncategorized = company.account_transactions
      .where(chart_of_account_id: nil)
      .limit(200)
      .pluck(:description, :merchant_name, :amount)

    return [] if uncategorized.empty?

    # Gather existing categorizations for context
    categorized_samples = company.account_transactions
      .where.not(chart_of_account_id: nil)
      .includes(:chart_of_account)
      .limit(200)
      .map { |t| { description: t.description, merchant: t.merchant_name, category: t.chart_of_account.name } }

    existing_rules = company.categorization_rules.pluck(:match_field, :match_type, :match_value)
    categories = company.chart_of_accounts.active.pluck(:id, :name, :account_type)

    prompt = <<~P
      Analyze these uncategorized transactions and suggest categorization rules.

      UNCATEGORIZED TRANSACTIONS (description | merchant | amount):
      #{uncategorized.first(50).map { |d, m, a| "#{d} | #{m} | $#{a}" }.join("\n")}

      EXISTING CATEGORIZED EXAMPLES:
      #{categorized_samples.first(30).map { |s| "#{s[:description]} | #{s[:merchant]} → #{s[:category]}" }.join("\n")}

      EXISTING RULES (already created, don't duplicate):
      #{existing_rules.map { |f, t, v| "#{f} #{t} '#{v}'" }.join("\n")}

      AVAILABLE CATEGORIES:
      #{categories.map { |id, name, type| "#{id}: #{name} (#{type})" }.join("\n")}

      Suggest rules that would categorize the uncategorized transactions. Look for patterns in:
      - Merchant names (exact or contains)
      - Description keywords (contains or starts_with)
      - Common vendor patterns

      Return JSON:
      {
        "suggestions": [
          {
            "match_field": "merchant_name",
            "match_type": "contains",
            "match_value": "STARBUCKS",
            "chart_of_account_id": 123,
            "chart_of_account_name": "Meals & Entertainment",
            "reason": "Multiple Starbucks transactions found",
            "estimated_matches": 5,
            "confidence": 90
          }
        ]
      }

      Only suggest rules with confidence >= 70. Be specific with patterns to avoid false positives.
    P

    response = call_ai(prompt)
    result = JSON.parse(response)
    (result['suggestions'] || []).map do |s|
      {
        match_field: s['match_field'],
        match_type: s['match_type'],
        match_value: s['match_value'],
        chart_of_account_id: s['chart_of_account_id'],
        chart_of_account_name: s['chart_of_account_name'],
        reason: s['reason'],
        estimated_matches: s['estimated_matches'],
        confidence: s['confidence']
      }
    end
  rescue => e
    Rails.logger.error "AI rule suggestion error: #{e.message}"
    []
  end

  private

  def self.call_ai(prompt)
    api_key = Rails.application.credentials.dig(:openai, :api_key) || ENV['OPENAI_API_KEY']
    return '{"suggestions":[]}' unless api_key

    uri = URI('https://api.openai.com/v1/chat/completions')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    body = {
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: 'You are an expert bookkeeper who creates categorization rules for transaction data. Analyze patterns and suggest rules. Return ONLY valid JSON.' },
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
    JSON.parse(response.body).dig('choices', 0, 'message', 'content') || '{"suggestions":[]}'
  end
end
