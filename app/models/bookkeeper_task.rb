class BookkeeperTask < ApplicationRecord
  belongs_to :company
  belongs_to :assigned_to, class_name: 'User', optional: true

  scope :pending, -> { where(status: 'pending') }
  scope :in_progress, -> { where(status: 'in_progress') }
  scope :open_tasks, -> { where(status: ['pending', 'in_progress']) }
  scope :completed, -> { where(status: 'completed') }
  scope :by_priority, -> { order(Arel.sql("CASE priority WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'normal' THEN 3 WHEN 'low' THEN 4 END")) }
  scope :overdue, -> { where('due_date < ?', Time.current).where(status: ['pending', 'in_progress']) }
  scope :due_soon, -> { where(due_date: Time.current..(3.days.from_now)).where(status: ['pending', 'in_progress']) }

  TYPES = %w[
    categorize reconcile review_anomaly close_month
    follow_up receipt_match bank_reconnect
    missing_transactions duplicate_check vendor_review
  ].freeze

  def complete!(user = nil)
    update!(status: 'completed', completed_at: Time.current)
  end

  def dismiss!
    update!(status: 'dismissed')
  end

  def start!
    update!(status: 'in_progress')
  end
end
