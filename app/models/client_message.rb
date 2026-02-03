class ClientMessage < ApplicationRecord
  belongs_to :company
  belongs_to :user

  validates :body, presence: true

  scope :chronological, -> { order(created_at: :asc) }
  scope :recent, -> { order(created_at: :desc) }

  after_create :notify_mentioned_users

  private

  def notify_mentioned_users
    # Parse @[Name](id) mentions from body
    ids = body.scan(/@\[([^\]]+)\]\((\d+)\)/).map { |_, id| id.to_i }
    return if ids.empty?

    self.update_column(:mentioned_user_ids, ids)

    # Only notify users who are members of this company (or have global access)
    company_member_ids = company.users.pluck(:id)
    global_ids = User.where(role: %w[executive manager]).pluck(:id)
    valid_ids = ids & (company_member_ids + global_ids)

    valid_ids.each do |uid|
      next if uid == user_id # Don't notify yourself

      mentioned_user = User.find_by(id: uid)
      next unless mentioned_user

      Notification.notify!(
        company: company,
        user: mentioned_user,
        type: 'client_message_mention',
        title: "#{user.first_name} #{user.last_name} mentioned you in a message",
        body: body.truncate(200),
        data: {
          client_message_id: id,
          company_id: company_id,
          author_id: user_id
        }
      )
    end
  end
end
