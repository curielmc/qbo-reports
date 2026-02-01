class MonthEndClose < ApplicationRecord
  belongs_to :company
  belongs_to :user

  DEFAULT_CHECKLIST = {
    'categorize_all' => { label: 'All transactions categorized', completed: false },
    'reconcile_bank' => { label: 'Bank accounts reconciled', completed: false },
    'reconcile_cc' => { label: 'Credit cards reconciled', completed: false },
    'review_anomalies' => { label: 'Anomalies reviewed', completed: false },
    'match_receipts' => { label: 'Receipts matched', completed: false },
    'review_ar' => { label: 'Accounts receivable reviewed', completed: false },
    'review_ap' => { label: 'Accounts payable reviewed', completed: false },
    'journal_adjustments' => { label: 'Adjusting journal entries posted', completed: false },
    'review_pl' => { label: 'P&L reviewed', completed: false },
    'review_bs' => { label: 'Balance sheet reviewed', completed: false },
    'client_review' => { label: 'Sent to client for review', completed: false }
  }.freeze

  def self.open_or_create(company, user, period)
    find_or_create_by!(company: company, period: period.beginning_of_month) do |close|
      close.user = user
      close.checklist = DEFAULT_CHECKLIST.deep_dup
      close.status = 'open'
    end
  end

  def check!(step, user)
    return unless checklist&.key?(step)
    checklist[step]['completed'] = true
    checklist[step]['completed_by'] = user.id
    checklist[step]['completed_at'] = Time.current.iso8601
    self.status = all_complete? ? 'review' : 'in_progress'
    save!
  end

  def uncheck!(step)
    return unless checklist&.key?(step)
    checklist[step]['completed'] = false
    checklist[step].delete('completed_by')
    checklist[step].delete('completed_at')
    self.status = 'in_progress'
    save!
  end

  def close!(user)
    self.status = 'closed'
    self.closed_at = Time.current
    save!
  end

  def progress
    return 0 unless checklist&.any?
    completed = checklist.values.count { |v| v['completed'] }
    (completed.to_f / checklist.size * 100).round(0)
  end

  def all_complete?
    checklist&.values&.all? { |v| v['completed'] }
  end
end
