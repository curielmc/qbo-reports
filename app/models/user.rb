class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum role: { 
    executive: 'executive',
    manager: 'manager',
    advisor: 'advisor', 
    client: 'client',
    viewer: 'viewer'
  }

  has_many :household_users, dependent: :destroy
  has_many :households, through: :household_users

  validates :role, presence: true

  # --- Permission helpers ---

  # Can see all households?
  def global_access?
    executive? || manager?
  end

  # Can modify system settings and manage user roles?
  def admin_access?
    executive?
  end

  # Can create/edit/delete data?
  def can_edit?
    executive? || manager? || advisor?
  end

  # Can see all users?
  def can_see_users?
    executive? || manager?
  end

  # Households this user can access
  def accessible_households
    return Household.all if global_access?
    households
  end

  def can_manage_household?(household)
    return true if global_access?
    households.include?(household)
  end

  # Can this user edit data in a household?
  def can_edit_household?(household)
    return true if executive?
    return true if manager? # limited edit
    return true if advisor? && households.include?(household)
    false
  end

  # Can this user manage other users?
  def can_manage_users?
    executive?
  end

  # Can this user view reports?
  def can_view_reports?(household)
    can_manage_household?(household)
  end
end
