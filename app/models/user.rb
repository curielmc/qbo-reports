class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum role: { 
    admin: 'admin', 
    executive: 'executive',
    advisor: 'advisor', 
    client: 'client' 
  }

  has_many :household_users, dependent: :destroy
  has_many :households, through: :household_users
  has_many :advisor_households, -> { where(household_users: { role: 'advisor' }) }, 
           through: :household_users, source: :household
  has_many :client_households, -> { where(household_users: { role: 'client' }) }, 
           through: :household_users, source: :household

  validates :role, presence: true

  def accessible_households
    return Household.all if admin? || executive?
    households
  end

  def can_manage_household?(household)
    return true if admin? || executive?
    households.include?(household)
  end
end
