class Transaction < ApplicationRecord
  belongs_to :account
  belongs_to :chart_of_account, optional: true
  has_one :company, through: :account

  scope :cleared, -> { where(pending: false) }
  scope :pending, -> { where(pending: true) }
  scope :by_date, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :income, -> { joins(:chart_of_account).where(chart_of_accounts: { account_type: 'income' }) }
  scope :expense, -> { joins(:chart_of_account).where(chart_of_accounts: { account_type: 'expense' }) }

  validates :date, :amount, :description, presence: true

  def categorized?
    chart_of_account.present?
  end
end
