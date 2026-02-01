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

    uncategorized = company.transactions.where(chart_of_account_id: nil)
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
      transactions = coa.transactions.where.not(merchant_name: [nil, ''])
      
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
end
