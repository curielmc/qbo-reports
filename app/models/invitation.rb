class Invitation < ApplicationRecord
  belongs_to :company, optional: true
  belongs_to :invited_by, class_name: 'User'

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token, presence: true, uniqueness: true
  validates :role, presence: true, inclusion: { in: %w[executive manager advisor client viewer] }
  validates :expires_at, presence: true

  before_validation :generate_token, on: :create
  before_validation :set_expiration, on: :create

  scope :pending, -> { where(accepted_at: nil).where('expires_at > ?', Time.current) }
  scope :expired, -> { where(accepted_at: nil).where('expires_at <= ?', Time.current) }
  scope :accepted, -> { where.not(accepted_at: nil) }

  def pending?
    accepted_at.nil? && expires_at > Time.current
  end

  def expired?
    accepted_at.nil? && expires_at <= Time.current
  end

  def accepted?
    accepted_at.present?
  end

  def accept!(user)
    update!(accepted_at: Time.current)
    # Add user to company if specified
    if company.present?
      CompanyUser.find_or_create_by!(user: user, company: company) do |hu|
        hu.role = role == 'client' ? 'client' : 'advisor'
      end
    end
  end

  def invite_url
    "#{ENV['APP_URL'] || 'http://localhost:6000'}/invite/#{token}"
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end

  def set_expiration
    self.expires_at ||= 7.days.from_now
  end
end
