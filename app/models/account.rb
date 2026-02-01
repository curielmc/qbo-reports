class Account < ApplicationRecord
  belongs_to :household
  has_many :transactions, dependent: :destroy

  enum account_type: {
    checking: 'checking',
    savings: 'savings',
    credit_card: 'credit_card',
    investment: 'investment',
    loan: 'loan',
    mortgage: 'mortgage',
    other: 'other'
  }

  validates :name, :account_type, presence: true
  validates :plaid_account_id, uniqueness: true, allow_nil: true
end
