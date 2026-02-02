class Transaction < ApplicationRecord
  belongs_to :account
  belongs_to :chart_of_account, optional: true
  belongs_to :reconciliation, optional: true
  has_one :company, through: :account
  has_one :journal_entry, dependent: :destroy

  scope :cleared, -> { where(pending: false) }
  scope :pending, -> { where(pending: true) }
  scope :by_date, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :income, -> { joins(:chart_of_account).where(chart_of_accounts: { account_type: 'income' }) }
  scope :expense, -> { joins(:chart_of_account).where(chart_of_accounts: { account_type: 'expense' }) }

  validates :date, :amount, :description, presence: true

  # ✨ AUTOMATIC DOUBLE-ENTRY ✨
  # When a transaction gets categorized, create the journal entry automatically.
  # When it gets uncategorized, remove it. The user never sees this.
  after_save :sync_journal_entry
  after_destroy :cleanup_journal_entry

  def categorized?
    chart_of_account.present?
  end

  private

  def sync_journal_entry
    if saved_change_to_chart_of_account_id?
      if chart_of_account_id.present?
        # Categorized → create/update double-entry
        JournalEntry.from_transaction(self)
      else
        # Uncategorized → remove journal entry
        JournalEntry.remove_for_transaction(self)
      end
    end
  end

  def cleanup_journal_entry
    JournalEntry.remove_for_transaction(self)
  end
end
