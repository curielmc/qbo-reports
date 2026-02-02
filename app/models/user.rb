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

  has_many :company_users, dependent: :destroy
  has_many :companies, through: :company_users
  has_many :api_keys, dependent: :destroy

  validates :role, presence: true

  # --- Permission helpers ---

  # Can see all companies?
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

  # Is this user a bookkeeper for any company?
  def bookkeeper?
    company_users.bookkeepers.exists? || executive? || manager?
  end

  # Role in a specific company
  def role_in(company)
    return 'owner' if executive?
    company_users.find_by(company: company)&.role || 'viewer'
  end

  def bookkeeper_for?(company)
    return true if executive? || manager?
    cu = company_users.find_by(company: company)
    cu&.bookkeeper?
  end

  def can_edit_in?(company)
    return true if executive? || manager?
    cu = company_users.find_by(company: company)
    cu&.can_edit?
  end

  # Companies this user can access
  def accessible_companies
    return Company.all if global_access?
    companies
  end

  def can_manage_company?(company)
    return true if global_access?
    companies.include?(company)
  end

  # Can this user edit data in a company?
  def can_edit_company?(company)
    return true if executive?
    return true if manager? # limited edit
    return true if advisor? && companies.include?(company)
    false
  end

  # Can this user manage other users?
  def can_manage_users?
    executive?
  end

  # Can this user view reports?
  def can_view_reports?(company)
    can_manage_company?(company)
  end
end
