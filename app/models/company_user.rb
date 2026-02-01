class CompanyUser < ApplicationRecord
  belongs_to :user
  belongs_to :company

  validates :user_id, uniqueness: { scope: :company_id }

  ROLES = %w[owner bookkeeper editor viewer].freeze
  validates :role, inclusion: { in: ROLES }, allow_nil: true

  scope :owners, -> { where(role: 'owner') }
  scope :bookkeepers, -> { where(role: 'bookkeeper') }
  scope :editors, -> { where(role: ['owner', 'bookkeeper', 'editor']) }

  def owner?
    role == 'owner'
  end

  def bookkeeper?
    role.in?(%w[owner bookkeeper])
  end

  def can_edit?
    role.in?(%w[owner bookkeeper editor])
  end

  def viewer?
    role == 'viewer'
  end
end
