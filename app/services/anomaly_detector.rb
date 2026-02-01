class AnomalyDetector
  def initialize(company)
    @company = company
  end

  # Run all anomaly checks and return alerts
  def check_all
    alerts = []
    alerts += unusual_amounts
    alerts += spending_spikes
    alerts += new_vendors
    alerts += uncategorized_alert
    alerts.sort_by { |a| -a[:severity] }
  end

  private

  # Transactions much larger than usual for that vendor
  def unusual_amounts
    alerts = []
    recent = @company.transactions.where(date: 7.days.ago..Date.current, pending: false)
      .where.not(merchant_name: [nil, ''])

    recent.each do |txn|
      history = @company.transactions
        .where(merchant_name: txn.merchant_name)
        .where.not(id: txn.id)
        .where(pending: false)

      next if history.count < 3

      avg = history.average(:amount).to_f.abs
      stddev = Math.sqrt(history.pluck(:amount).map { |a| (a.abs - avg) ** 2 }.sum / history.count)
      next if stddev == 0

      z_score = (txn.amount.abs - avg) / stddev
      next unless z_score > 2.0

      alerts << {
        type: 'unusual_amount',
        severity: [z_score.round(1) * 10, 100].min.to_i,
        message: "#{txn.description}: $#{'%.2f' % txn.amount.abs} is #{z_score.round(1)}x standard deviations from the $#{'%.2f' % avg} average for #{txn.merchant_name}",
        transaction_id: txn.id,
        date: txn.date
      }
    end

    alerts
  end

  # Monthly category spending significantly higher than average
  def spending_spikes
    alerts = []
    current_month_start = Date.current.beginning_of_month

    @company.chart_of_accounts.expense.active.each do |coa|
      current = coa.transactions.where(date: current_month_start..Date.current, pending: false).sum(:amount).abs

      # Average of previous 3 months
      monthly_avgs = (1..3).map do |i|
        ms = i.months.ago.beginning_of_month
        me = i.months.ago.end_of_month
        coa.transactions.where(date: ms..me, pending: false).sum(:amount).abs
      end

      avg = monthly_avgs.sum / 3.0
      next if avg < 100 # ignore tiny categories

      # Pro-rate current month
      days_in_month = Date.current.end_of_month.day
      days_passed = Date.current.day
      projected = (current / days_passed.to_f) * days_in_month

      pct_increase = avg > 0 ? ((projected - avg) / avg * 100) : 0
      next unless pct_increase > 50

      alerts << {
        type: 'spending_spike',
        severity: [pct_increase / 2, 100].min.to_i,
        message: "#{coa.name} is trending #{pct_increase.round(0)}% above average this month ($#{'%.0f' % projected} projected vs $#{'%.0f' % avg} avg)",
        category: coa.name,
        projected: projected,
        average: avg
      }
    end

    alerts
  end

  # New vendors in the last 7 days
  def new_vendors
    recent_merchants = @company.transactions
      .where(date: 7.days.ago..Date.current)
      .where.not(merchant_name: [nil, ''])
      .distinct.pluck(:merchant_name)

    new_ones = recent_merchants.select do |merchant|
      !@company.transactions
        .where(merchant_name: merchant)
        .where('date < ?', 7.days.ago)
        .exists?
    end

    return [] if new_ones.empty?

    [{
      type: 'new_vendors',
      severity: 20,
      message: "#{new_ones.size} new vendor(s) this week: #{new_ones.first(5).join(', ')}#{new_ones.size > 5 ? '...' : ''}",
      vendors: new_ones
    }]
  end

  # Uncategorized transactions piling up
  def uncategorized_alert
    count = @company.transactions.where(chart_of_account_id: nil).count
    return [] if count < 10

    [{
      type: 'uncategorized',
      severity: [count, 80].min,
      message: "#{count} uncategorized transactions need review",
      count: count
    }]
  end
end
