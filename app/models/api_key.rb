class ApiKey < ApplicationRecord
  belongs_to :user
  belongs_to :company

  validates :name, presence: true
  validates :token_digest, presence: true, uniqueness: true
  validates :prefix, presence: true

  scope :active, -> { where(active: true).where('expires_at IS NULL OR expires_at > ?', Time.current) }

  # Generate a new API key and return the raw token (only available at creation time)
  def self.generate!(user:, company:, name:, permissions: [], expires_at: nil)
    raw_token = "sk-#{SecureRandom.hex(24)}"
    prefix = raw_token[0..6] # "sk-xxxx"

    api_key = create!(
      user: user,
      company: company,
      name: name,
      token_digest: Digest::SHA256.hexdigest(raw_token),
      prefix: prefix,
      permissions: permissions,
      expires_at: expires_at
    )

    [api_key, raw_token]
  end

  # Find an API key by raw token
  def self.find_by_token(raw_token)
    return nil if raw_token.blank?

    digest = Digest::SHA256.hexdigest(raw_token)
    active.find_by(token_digest: digest)
  end

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end

  def can?(permission)
    return true if permissions.blank? # empty = all permissions
    permissions.include?(permission.to_s)
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def revoke!
    update!(active: false)
  end
end
