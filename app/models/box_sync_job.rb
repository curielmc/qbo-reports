class BoxSyncJob < ApplicationRecord
  belongs_to :company
  belongs_to :user

  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where(status: %w[pending scanning importing]) }

  def progress_pct
    return 0 if total_files.to_i.zero?
    ((processed_files.to_f / total_files) * 100).round
  end

  def running?
    status.in?(%w[pending scanning importing])
  end
end
