class ChartOfAccount < ApplicationRecord
  belongs_to :company
  has_many :account_transactions, dependent: :nullify
  has_many :journal_lines, dependent: :restrict_with_error
  has_many :categorization_rules, dependent: :destroy

  enum account_type: {
    asset: 'asset',
    liability: 'liability', 
    equity: 'equity',
    income: 'income',
    expense: 'expense'
  }

  validates :name, :account_type, presence: true
  validates :code, uniqueness: { scope: :company_id }, allow_nil: true

  scope :active, -> { where(active: true) }

  # Get the balance from the general ledger (journal lines)
  # Assets & Expenses: normal debit balance (debit - credit)
  # Liabilities, Equity, Income: normal credit balance (credit - debit)
  def balance(as_of: Date.current)
    lines = journal_lines.joins(:journal_entry)
      .where(journal_entries: { posted: true })
      .where('journal_entries.entry_date <= ?', as_of)

    total_debit = lines.sum(:debit)
    total_credit = lines.sum(:credit)

    if %w[asset expense].include?(account_type)
      total_debit - total_credit
    else
      total_credit - total_debit
    end
  end

  # Balance for a date range (for P&L)
  def period_balance(start_date:, end_date:)
    lines = journal_lines.joins(:journal_entry)
      .where(journal_entries: { posted: true })
      .where(journal_entries: { entry_date: start_date..end_date })

    total_debit = lines.sum(:debit)
    total_credit = lines.sum(:credit)

    if %w[asset expense].include?(account_type)
      total_debit - total_credit
    else
      total_credit - total_debit
    end
  end
end
