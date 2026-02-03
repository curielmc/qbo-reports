class Notification < ApplicationRecord
  belongs_to :company
  belongs_to :user

  scope :unread, -> { where(read: false) }
  scope :recent, -> { order(created_at: :desc).limit(50) }

  TYPES = %w[
    anomaly low_balance uncategorized_pileup
    reconciliation_due receipt_matched receipt_unmatched
    credit_low credit_exhausted invitation_accepted
    monthly_report_ready comment_mention client_message_mention
  ].freeze

  def self.notify!(company:, user:, type:, title:, body: nil, data: nil)
    create!(
      company: company,
      user: user,
      notification_type: type,
      title: title,
      body: body,
      data: data
    )
  end

  def mark_read!
    update!(read: true)
  end
end
