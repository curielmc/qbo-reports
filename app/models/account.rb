class Account < ApplicationRecord
  belongs_to :company
  belongs_to :plaid_item, optional: true
  has_many :transactions, dependent: :destroy

  enum account_type: {
    checking: 'checking',
    savings: 'savings',
    credit_card: 'credit_card',
    credit: 'credit',
    investment: 'investment',
    loan: 'loan',
    mortgage: 'mortgage',
    depository: 'depository',
    brokerage: 'brokerage',
    other: 'other'
  }

  scope :active, -> { where(active: true) }
  scope :linked, -> { where.not(plaid_account_id: nil) }

  validates :name, :account_type, presence: true
  validates :plaid_account_id, uniqueness: true, allow_nil: true
end
