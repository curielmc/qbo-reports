class Receipt < ApplicationRecord
  belongs_to :company
  belongs_to :user
  belongs_to :account_transaction, foreign_key: 'transaction_id', optional: true

  scope :pending, -> { where(status: 'pending') }
  scope :unmatched, -> { where(status: 'unmatched') }
  scope :matched, -> { where(status: 'matched') }

  # Try to auto-match to an existing transaction
  def auto_match!
    return if amount.blank? || receipt_date.blank?

    # Look for transactions within 3 days and similar amount
    candidates = company.account_transactions
      .where(date: (receipt_date - 3.days)..(receipt_date + 3.days))
      .where('ABS(amount) BETWEEN ? AND ?', amount.abs * 0.95, amount.abs * 1.05)
      .where(reconciliation_status: 'uncleared')
      .order(Arel.sql("ABS(ABS(amount) - #{amount.abs}) ASC"))

    # If vendor matches too, even better
    if vendor.present?
      vendor_match = candidates.find { |t|
        t.merchant_name&.downcase&.include?(vendor.downcase) ||
        t.description&.downcase&.include?(vendor.downcase)
      }
      if vendor_match
        match_to!(vendor_match)
        return
      end
    end

    # Otherwise take the closest amount match
    if candidates.any?
      match_to!(candidates.first)
    else
      update!(status: 'unmatched')
    end
  end

  def match_to!(txn)
    update!(account_transaction: txn, status: 'matched')
  end
end
