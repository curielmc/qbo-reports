class Company < ApplicationRecord
  has_many :company_users, dependent: :destroy
  has_many :users, through: :company_users
  has_many :advisors, -> { where(company_users: { role: 'advisor' }) }, 
           through: :company_users, source: :user
  has_many :clients, -> { where(company_users: { role: 'client' }) }, 
           through: :company_users, source: :user
  
  has_many :accounts, dependent: :destroy
  has_many :plaid_items, dependent: :destroy
  has_many :transactions, through: :accounts
  has_many :chart_of_accounts, dependent: :destroy
  has_many :categorization_rules, dependent: :destroy
  has_many :chat_messages, dependent: :destroy
  has_many :journal_entries, dependent: :destroy
  has_many :statement_uploads, dependent: :destroy

  validates :name, presence: true
end
