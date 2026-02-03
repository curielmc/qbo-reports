class JournalEntry < ApplicationRecord
  belongs_to :company
  belongs_to :account_transaction, foreign_key: 'transaction_id', optional: true
  has_many :journal_lines, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy

  validates :entry_date, presence: true
  validate :must_balance

  scope :posted, -> { where(posted: true) }
  scope :by_date, ->(start_date, end_date) { where(entry_date: start_date..end_date) }

  # Verify debits == credits
  def must_balance
    return if journal_lines.empty?
    total_debits = journal_lines.sum(&:debit)
    total_credits = journal_lines.sum(&:credit)
    unless (total_debits - total_credits).abs < 0.01
      errors.add(:base, "Entry doesn't balance: debits ($#{total_debits}) ≠ credits ($#{total_credits})")
    end
  end

  def balanced?
    (journal_lines.sum(&:debit) - journal_lines.sum(&:credit)).abs < 0.01
  end

  # === AUTOMATIC DOUBLE-ENTRY FACTORY METHODS ===

  # Create journal entry from a bank transaction + its category
  # This is the core magic: user categorizes a transaction, we handle the accounting
  def self.from_transaction(transaction)
    return nil unless transaction.chart_of_account_id.present?
    return nil unless transaction.account.present?

    company = transaction.account.company
    
    # Find or create the bank's corresponding CoA entry
    bank_coa = find_or_create_bank_coa(company, transaction.account)

    # Determine debit/credit based on transaction type
    amount = transaction.amount.abs
    category_coa = transaction.chart_of_account

    entry = company.journal_entries.find_or_initialize_by(account_transaction: transaction)
    entry.entry_date = transaction.date
    entry.memo = transaction.description
    entry.source = transaction.plaid_transaction_id? ? 'plaid' : 'manual'
    entry.journal_lines.destroy_all if entry.persisted?

    if transaction.amount < 0
      # Money going OUT (expense, asset purchase, liability payment)
      # Debit the category (expense goes up, or asset goes up)
      # Credit the bank (cash goes down)
      entry.journal_lines.build(chart_of_account: category_coa, debit: amount, credit: 0, memo: transaction.description)
      entry.journal_lines.build(chart_of_account: bank_coa, debit: 0, credit: amount, memo: "Payment: #{transaction.description}")
    else
      # Money coming IN (income, refund, deposit)
      # Debit the bank (cash goes up)
      # Credit the category (income goes up)
      entry.journal_lines.build(chart_of_account: bank_coa, debit: amount, credit: 0, memo: "Deposit: #{transaction.description}")
      entry.journal_lines.build(chart_of_account: category_coa, debit: 0, credit: amount, memo: transaction.description)
    end

    entry.save!
    entry
  end

  # Remove journal entry when transaction is uncategorized
  def self.remove_for_transaction(transaction)
    JournalEntry.where(account_transaction: transaction).destroy_all
  end

  # Transfer between accounts (e.g., checking → savings)
  def self.create_transfer(company, from_account, to_account, amount, date, memo = nil)
    from_coa = find_or_create_bank_coa(company, from_account)
    to_coa = find_or_create_bank_coa(company, to_account)

    entry = company.journal_entries.build(
      entry_date: date,
      memo: memo || "Transfer: #{from_account.name} → #{to_account.name}",
      source: 'manual'
    )
    entry.journal_lines.build(chart_of_account: to_coa, debit: amount, credit: 0)
    entry.journal_lines.build(chart_of_account: from_coa, debit: 0, credit: amount)
    entry.save!
    entry
  end

  # Manual adjusting entry (for accountants)
  def self.create_adjustment(company, lines_data, date, memo)
    entry = company.journal_entries.build(entry_date: date, memo: memo, source: 'manual')
    lines_data.each do |line|
      coa = company.chart_of_accounts.find(line[:chart_of_account_id])
      entry.journal_lines.build(
        chart_of_account: coa,
        debit: line[:debit] || 0,
        credit: line[:credit] || 0,
        memo: line[:memo]
      )
    end
    entry.save!
    entry
  end

  private

  # Every bank account gets a matching Chart of Account entry (asset type)
  # This maps Plaid accounts to the general ledger automatically
  def self.find_or_create_bank_coa(company, account)
    # Look for existing CoA linked to this account
    coa_name = "#{account.name} (#{account.mask || account.account_type})"
    
    account_type = case account.account_type
    when 'credit', 'credit_card' then 'liability'
    when 'loan', 'mortgage' then 'liability'
    else 'asset'
    end

    company.chart_of_accounts.find_or_create_by!(name: coa_name) do |coa|
      coa.account_type = account_type
      coa.code = "1#{account.id.to_s.rjust(3, '0')}" # Auto-generate code
    end
  end
end
