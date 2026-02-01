class Reconciliation < ApplicationRecord
  belongs_to :company
  belongs_to :account
  belongs_to :user
  has_many :transactions

  scope :in_progress, -> { where(status: 'in_progress') }
  scope :completed, -> { where(status: 'completed') }

  def cleared_transactions
    account.transactions
      .where(reconciliation_id: id)
      .where(reconciliation_status: 'cleared')
  end

  def cleared_total
    cleared_transactions.sum(:amount)
  end

  def recalculate!
    self.book_balance = cleared_total
    self.difference = (statement_balance - book_balance).round(2)
    self.status = difference.zero? ? 'completed' : 'in_progress'
    save!
  end
end
