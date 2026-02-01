class JournalLine < ApplicationRecord
  belongs_to :journal_entry
  belongs_to :chart_of_account

  validates :debit, :credit, numericality: { greater_than_or_equal_to: 0 }
  validate :not_both_zero

  scope :debits, -> { where('debit > 0') }
  scope :credits, -> { where('credit > 0') }

  def amount
    debit > 0 ? debit : -credit
  end

  def net
    debit - credit
  end

  private

  def not_both_zero
    if debit == 0 && credit == 0
      errors.add(:base, "Either debit or credit must be greater than zero")
    end
  end
end
