class Invitation < ApplicationRecord
  belongs_to :company
  belongs_to :invited_by, class_name: 'User'

  before_create :generate_token
  before_create :set_expiry

  ROLES = %w[owner bookkeeper editor viewer].freeze

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: ROLES }

  scope :pending, -> { where(status: 'pending').where('expires_at > ?', Time.current) }
  scope :expired, -> { where(status: 'pending').where('expires_at <= ?', Time.current) }

  def accept!(user)
    return false if status != 'pending' || expires_at < Time.current

    transaction do
      update!(status: 'accepted', accepted_at: Time.current)
      CompanyUser.find_or_create_by!(company: company, user: user) do |cu|
        cu.role = role
      end
    end
    true
  end

  def expired?
    expires_at < Time.current
  end

  private

  def generate_token
    self.token = SecureRandom.urlsafe_base64(32)
  end

  def set_expiry
    self.expires_at ||= 7.days.from_now
  end
end
