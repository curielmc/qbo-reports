class AccountTransaction < ApplicationRecord
  self.table_name = "transactions"

  belongs_to :account
  belongs_to :chart_of_account, optional: true
  belongs_to :reconciliation, optional: true
  has_one :company, through: :account
  has_one :journal_entry, foreign_key: 'transaction_id', dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy

  # Ledger status: pending (needs review), posted (in ledger), excluded (ignored)
  LEDGER_STATUSES = %w[pending posted excluded].freeze
  validates :ledger_status, inclusion: { in: LEDGER_STATUSES }

  # Bank clearing status scopes (from Plaid)
  scope :bank_cleared, -> { where(pending: false) }
  scope :bank_pending, -> { where(pending: true) }

  # Ledger status scopes
  scope :ledger_pending, -> { where(ledger_status: 'pending') }
  scope :ledger_posted, -> { where(ledger_status: 'posted') }
  scope :ledger_excluded, -> { where(ledger_status: 'excluded') }

  scope :by_date, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :income, -> { joins(:chart_of_account).where(chart_of_accounts: { account_type: 'income' }) }
  scope :expense, -> { joins(:chart_of_account).where(chart_of_accounts: { account_type: 'expense' }) }

  validates :date, :amount, :description, presence: true

  after_save :sync_journal_entry
  after_destroy :cleanup_journal_entry

  def categorized?
    chart_of_account.present?
  end

  def posted?
    ledger_status == 'posted'
  end

  def excluded?
    ledger_status == 'excluded'
  end

  # Post transaction to ledger - creates journal entry
  def post_to_ledger!
    raise "Transaction must be categorized before posting" unless categorized?
    update!(ledger_status: 'posted')
  end

  # Exclude transaction from ledger
  def exclude_from_ledger!
    update!(ledger_status: 'excluded')
  end

  # Move back to pending (unpost)
  def unpost!
    update!(ledger_status: 'pending')
  end

  private

  def sync_journal_entry
    # Only create/update journal entries for posted transactions
    if ledger_status == 'posted' && chart_of_account_id.present?
      if saved_change_to_ledger_status? || saved_change_to_chart_of_account_id? || saved_change_to_amount?
        JournalEntry.from_transaction(self)
      end
    elsif saved_change_to_ledger_status? && ledger_status != 'posted'
      # Remove journal entry if unposted or excluded
      JournalEntry.remove_for_transaction(self)
    elsif saved_change_to_chart_of_account_id? && chart_of_account_id.nil? && posted?
      # If category removed from posted transaction, unpost it
      JournalEntry.remove_for_transaction(self)
    end
  end

  def cleanup_journal_entry
    JournalEntry.remove_for_transaction(self)
  end
end
