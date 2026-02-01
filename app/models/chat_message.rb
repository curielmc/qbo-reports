class ChatMessage < ApplicationRecord
  belongs_to :user
  belongs_to :company

  validates :role, presence: true, inclusion: { in: %w[user assistant] }
  validates :content, presence: true

  scope :recent, -> { order(created_at: :desc).limit(20) }
  scope :conversation, -> { order(created_at: :asc) }
end
