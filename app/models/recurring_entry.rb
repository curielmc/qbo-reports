class RecurringEntry < ApplicationRecord
  belongs_to :company
  belongs_to :created_by, class_name: 'User'

  scope :active, -> { where(active: true) }
  scope :due, -> { active.where('next_run_date <= ?', Date.current) }

  FREQUENCIES = %w[weekly biweekly monthly quarterly annually].freeze

  validates :name, presence: true
  validates :frequency, inclusion: { in: FREQUENCIES }
  validate :lines_must_balance

  def run!
    return unless due?

    entry = company.journal_entries.build(
      entry_date: next_run_date,
      memo: "#{name} (recurring)",
      source: 'recurring',
      entry_type: 'standard',
      posted: auto_post,
      recurring_template_id: id
    )

    (self.lines || []).each do |line|
      coa = company.chart_of_accounts.find_by(id: line['chart_of_account_id'])
      next unless coa
      entry.journal_lines.build(
        chart_of_account: coa,
        debit: line['debit'] || 0,
        credit: line['credit'] || 0,
        memo: line['memo']
      )
    end

    entry.save!
    self.times_run += 1
    advance_next_run!
    entry
  end

  def due?
    active? && next_run_date && next_run_date <= Date.current &&
      (end_date.nil? || next_run_date <= end_date)
  end

  def advance_next_run!
    self.next_run_date = case frequency
    when 'weekly' then next_run_date + 7.days
    when 'biweekly' then next_run_date + 14.days
    when 'monthly' then next_run_date + 1.month
    when 'quarterly' then next_run_date + 3.months
    when 'annually' then next_run_date + 1.year
    end
    save!
  end

  # Run all due recurring entries for a company
  def self.process_due(company)
    entries_created = 0
    company.recurring_entries.due.find_each do |recurring|
      recurring.run!
      entries_created += 1
    end
    entries_created
  end

  private

  def lines_must_balance
    return if lines.blank?
    total_debits = lines.sum { |l| l['debit'].to_f }
    total_credits = lines.sum { |l| l['credit'].to_f }
    unless (total_debits - total_credits).abs < 0.01
      errors.add(:base, "Lines don't balance: debits ($#{total_debits}) ≠ credits ($#{total_credits})")
    end
  end
end
