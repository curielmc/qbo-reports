class AuditLog < ApplicationRecord
  belongs_to :company
  belongs_to :user

  scope :recent, -> { order(created_at: :desc).limit(100) }
  scope :for_resource, ->(type, id) { where(resource_type: type, resource_id: id) }

  def self.record!(company:, user:, action:, resource: nil, changes: nil, ip: nil)
    create!(
      company: company,
      user: user,
      action: action,
      resource_type: resource&.class&.name,
      resource_id: resource&.id,
      changes_made: changes,
      ip_address: ip
    )
  end
end
