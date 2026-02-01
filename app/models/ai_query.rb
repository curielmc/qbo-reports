class AiQuery < ApplicationRecord
  belongs_to :company
  belongs_to :user

  scope :this_cycle, ->(start_date) { where('created_at >= ?', start_date || Date.current.beginning_of_month) }
  scope :by_action, ->(action) { where(action: action) }

  # Pricing tiers for different query types
  QUERY_COSTS = {
    'chat' => 5,          # $0.05 — simple question
    'categorize' => 3,    # $0.03 — categorization
    'suggest_categories' => 10, # $0.10 — AI analysis
    'report' => 8,        # $0.08 — report generation
    'parse_statement' => 25, # $0.25 — statement parsing (heavier)
    'reconcile' => 10,    # $0.10 — reconciliation
    'anomalies' => 8,     # $0.08 — anomaly detection
    'coa_health' => 10,   # $0.10 — COA analysis
    'migration' => 50,    # $0.50 — QB migration (one-time heavy)
    'default' => 5        # $0.05 — anything else
  }.freeze

  def self.cost_for(action)
    QUERY_COSTS[action] || QUERY_COSTS['default']
  end
end
