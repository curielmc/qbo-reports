class AccountTransaction < ApplicationRecord
  self.table_name = "transactions"

  belongs_to :account
  belongs_to :chart_of_account, optional: true
  belongs_to :reconciliation, optional: true
  has_one :company, through: :account
  has_one :journal_entry, foreign_key: 'transaction_id', dependent: :destroy

  scope :cleared, -> { where(pending: false) }
  scope :pending, -> { where(pending: true) }
  scope :by_date, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :income, -> { joins(:chart_of_account).where(chart_of_accounts: { account_type: 'income' }) }
  scope :expense, -> { joins(:chart_of_account).where(chart_of_accounts: { account_type: 'expense' }) }

  validates :date, :amount, :description, presence: true

  after_save :sync_journal_entry
  after_destroy :cleanup_journal_entry

  def categorized?
    chart_of_account.present?
  end

  private

  def sync_journal_entry
    if saved_change_to_chart_of_account_id?
      if chart_of_account_id.present?
        JournalEntry.from_transaction(self)
      else
        JournalEntry.remove_for_transaction(self)
      end
    end
  end

  def cleanup_journal_entry
    JournalEntry.remove_for_transaction(self)
  end
end
