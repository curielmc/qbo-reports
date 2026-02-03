class Comment < ApplicationRecord
  belongs_to :company
  belongs_to :user
  belongs_to :commentable, polymorphic: true

  has_many :mentions, dependent: :destroy

  validates :body, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :chronological, -> { order(created_at: :asc) }

  after_create :process_mentions

  private

  def process_mentions
    # Extract @mentions from body text (matches @first_name last_name or @email)
    mentioned_emails = body.scan(/@\[([^\]]+)\]\((\d+)\)/).map { |_, id| id.to_i }

    return if mentioned_emails.empty?

    # Find users who are members of this company
    company_user_ids = company.users.where(id: mentioned_emails).pluck(:id)

    company_user_ids.each do |uid|
      next if uid == user_id # Don't notify yourself

      mentions.create!(user_id: uid)

      mentioned_user = User.find(uid)
      Notification.notify!(
        company: company,
        user: mentioned_user,
        type: 'comment_mention',
        title: "#{user.first_name} #{user.last_name} mentioned you in a comment",
        body: body.truncate(200),
        data: {
          comment_id: id,
          commentable_type: commentable_type,
          commentable_id: commentable_id,
          author_id: user_id
        }
      )
    end
  end
end
