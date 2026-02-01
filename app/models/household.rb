class Household < ApplicationRecord
  has_many :household_users, dependent: :destroy
  has_many :users, through: :household_users
  has_many :advisors, -> { where(household_users: { role: 'advisor' }) }, 
           through: :household_users, source: :user
  has_many :clients, -> { where(household_users: { role: 'client' }) }, 
           through: :household_users, source: :user
  
  has_many :accounts, dependent: :destroy
  has_many :plaid_items, dependent: :destroy
  has_many :transactions, through: :accounts
  has_many :chart_of_accounts, dependent: :destroy

  validates :name, presence: true
end
