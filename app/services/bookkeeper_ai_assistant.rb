class BookkeeperAiAssistant
  def initialize(user)
    @user = user
    @companies = user.accessible_companies
  end

  # ============================================
  # MULTI-CLIENT HEALTH DASHBOARD
  # ============================================

  def client_health_scores
    @companies.map do |company|
      score = calculate_health(company)
      {
        company_id: company.id,
        name: company.name,
        score: score[:score],
        grade: score[:grade],
        issues: score[:issues],
        last_transaction_date: company.account_transactions.maximum(:date),
        uncategorized: company.account_transactions.where(chart_of_account_id: nil).count,
        unreconciled_accounts: unreconciled_count(company),
        unmatched_receipts: company.receipts.unmatched.count
      }
    end.sort_by { |c| c[:score] }
  end

  # ============================================
  # AI TASK GENERATION
  # ============================================

  # Scan all clients and generate prioritized tasks
  def generate_tasks
    tasks_created = 0

    @companies.each do |company|
      tasks_created += generate_categorization_tasks(company)
      tasks_created += generate_reconciliation_tasks(company)
      tasks_created += generate_anomaly_tasks(company)
      tasks_created += generate_receipt_tasks(company)
      tasks_created += generate_bank_health_tasks(company)
      tasks_created += generate_month_end_tasks(company)
    end

    tasks_created
  end

  # ============================================
  # ANOMALY DETECTION
  # ============================================

  def detect_anomalies(company)
    anomalies = []

    # 1. Unusually large transactions (>3x average for that category)
    company.chart_of_accounts.active.each do |coa|
      txns = coa.account_transactions.where(date: 90.days.ago..Date.current)
      next if txns.count < 5

      avg = txns.average(:amount).to_f.abs
      stddev = Math.sqrt(txns.pluck(:amount).map { |a| (a.abs - avg) ** 2 }.sum / txns.count)
      threshold = avg + (3 * stddev)

      outliers = txns.where('ABS(amount) > ?', threshold)
      outliers.each do |txn|
        anomalies << {
          type: 'unusual_amount',
          severity: 'high',
          transaction_id: txn.id,
          message: "#{txn.merchant_name || txn.description}: $#{'%.2f' % txn.amount.abs} is #{(txn.amount.abs / avg).round(1)}x the average for #{coa.name}",
          date: txn.date
        }
      end
    end

    # 2. Duplicate transactions (same amount + date + similar description)
    recent = company.account_transactions.where(date: 30.days.ago..Date.current).order(:date, :amount)
    recent.each_cons(2) do |a, b|
      if a.date == b.date && a.amount == b.amount && a.id != b.id
        desc_sim = (a.description&.downcase || '') == (b.description&.downcase || '') ||
                   (a.merchant_name&.downcase || '') == (b.merchant_name&.downcase || '')
        if desc_sim
          anomalies << {
            type: 'possible_duplicate',
            severity: 'high',
            transaction_ids: [a.id, b.id],
            message: "Possible duplicate: #{a.merchant_name || a.description} for $#{'%.2f' % a.amount.abs} on #{a.date}",
            date: a.date
          }
        end
      end
    end

    # 3. Missing sequence (gaps in regular transactions like rent, payroll)
    regular = find_regular_transactions(company)
    regular.each do |pattern|
      last_date = pattern[:last_date]
      expected_next = last_date + pattern[:frequency_days].days
      if expected_next < Date.current - 5.days
        anomalies << {
          type: 'missing_recurring',
          severity: 'normal',
          message: "Expected #{pattern[:description]} (~$#{'%.2f' % pattern[:avg_amount]}) around #{expected_next.strftime('%b %d')} — hasn't appeared yet",
          expected_date: expected_next
        }
      end
    end

    # 4. Round number expenses (potential estimates needing receipts)
    company.account_transactions.where(date: 30.days.ago..Date.current)
      .where('amount < 0 AND amount = ROUND(amount, 0) AND ABS(amount) > 100')
      .each do |txn|
        anomalies << {
          type: 'round_number',
          severity: 'low',
          transaction_id: txn.id,
          message: "Round number expense: #{txn.merchant_name || txn.description} for exactly $#{'%.0f' % txn.amount.abs} — might be an estimate",
          date: txn.date
        }
      end

    anomalies.sort_by { |a| { 'high' => 0, 'normal' => 1, 'low' => 2 }[a[:severity]] }
  end

  # ============================================
  # SMART CATEGORIZATION SUGGESTIONS
  # ============================================

  # For bookkeepers: batch categorize across clients using AI
  def smart_categorize(company)
    uncategorized = company.account_transactions
      .where(chart_of_account_id: nil)
      .order(date: :desc)
      .limit(100)

    return [] if uncategorized.empty?

    # Group by merchant for efficiency
    by_merchant = uncategorized.group_by { |t| (t.merchant_name || t.description || '').downcase.strip }

    suggestions = []
    by_merchant.each do |merchant, txns|
      # Check if we've categorized this merchant before
      past = company.account_transactions
        .where('LOWER(merchant_name) = ? OR LOWER(description) = ?', merchant, merchant)
        .where.not(chart_of_account_id: nil)
        .limit(1)
        .first

      if past
        suggestions << {
          merchant: merchant,
          transaction_ids: txns.map(&:id),
          suggested_category_id: past.chart_of_account_id,
          suggested_category: past.chart_of_account.name,
          confidence: 95,
          reason: "Previously categorized as #{past.chart_of_account.name}"
        }
      else
        # Will use AI for unknown merchants (handled by BookkeeperAi)
        suggestions << {
          merchant: merchant,
          transaction_ids: txns.map(&:id),
          count: txns.size,
          total: txns.sum(&:amount),
          needs_ai: true
        }
      end
    end

    suggestions
  end

  # ============================================
  # VENDOR ANALYSIS
  # ============================================

  def vendor_summary(company)
    company.account_transactions
      .where(date: 90.days.ago..Date.current)
      .where.not(merchant_name: [nil, ''])
      .group(:merchant_name)
      .select(
        'merchant_name',
        'COUNT(*) as transaction_count',
        'SUM(amount) as total_amount',
        'AVG(amount) as avg_amount',
        'MIN(date) as first_date',
        'MAX(date) as last_date'
      )
      .order('total_amount ASC')
      .limit(50)
      .map { |v|
        {
          vendor: v.merchant_name,
          transactions: v.transaction_count,
          total: v.total_amount.round(2),
          average: v.avg_amount.round(2),
          first_seen: v.first_date,
          last_seen: v.last_date,
          frequency: v.transaction_count > 1 ?
            ((v.last_date - v.first_date).to_f / (v.transaction_count - 1)).round(0) : nil
        }
      }
  end

  private

  def calculate_health(company)
    issues = []
    score = 100

    # Uncategorized transactions
    uncategorized = company.account_transactions.where(chart_of_account_id: nil).count
    total = company.account_transactions.count
    if total > 0
      pct = (uncategorized.to_f / total * 100).round(0)
      if pct > 30
        score -= 30
        issues << "🔴 #{pct}% uncategorized (#{uncategorized} transactions)"
      elsif pct > 10
        score -= 15
        issues << "🟡 #{pct}% uncategorized (#{uncategorized} transactions)"
      elsif pct > 0
        score -= 5
        issues << "🟢 #{uncategorized} uncategorized"
      end
    end

    # Stale data (no recent transactions)
    last_txn = company.account_transactions.maximum(:date)
    if last_txn
      days_stale = (Date.current - last_txn).to_i
      if days_stale > 30
        score -= 25
        issues << "🔴 No transactions in #{days_stale} days — bank disconnected?"
      elsif days_stale > 14
        score -= 10
        issues << "🟡 Last transaction #{days_stale} days ago"
      end
    else
      score -= 40
      issues << "🔴 No transactions imported yet"
    end

    # Unreconciled
    unrecon = unreconciled_count(company)
    if unrecon > 0
      score -= (unrecon * 5)
      issues << "🟡 #{unrecon} accounts need reconciliation"
    end

    # Unmatched receipts
    unmatched = company.receipts.unmatched.count
    if unmatched > 5
      score -= 10
      issues << "🟡 #{unmatched} unmatched receipts"
    end

    grade = case score
    when 90..100 then 'A'
    when 80..89 then 'B'
    when 70..79 then 'C'
    when 60..69 then 'D'
    else 'F'
    end

    { score: [score, 0].max, grade: grade, issues: issues }
  end

  def unreconciled_count(company)
    company.accounts.count { |a|
      last_recon = a.reconciliations.completed.order(statement_date: :desc).first
      !last_recon || last_recon.statement_date < 30.days.ago
    }
  end

  def generate_categorization_tasks(company)
    count = company.account_transactions.where(chart_of_account_id: nil).count
    return 0 if count == 0

    existing = company.bookkeeper_tasks.open_tasks.where(task_type: 'categorize').exists?
    return 0 if existing

    priority = count > 50 ? 'high' : count > 20 ? 'normal' : 'low'
    company.bookkeeper_tasks.create!(
      assigned_to: @user,
      task_type: 'categorize',
      priority: priority,
      title: "Categorize #{count} transactions",
      description: "#{company.name} has #{count} uncategorized transactions.",
      estimated_minutes: (count * 0.3).ceil,
      due_date: 3.days.from_now,
      metadata: { uncategorized_count: count }
    )
    1
  end

  def generate_reconciliation_tasks(company)
    created = 0
    company.accounts.each do |account|
      last_recon = account.reconciliations.completed.order(statement_date: :desc).first
      next if last_recon && last_recon.statement_date >= 25.days.ago

      existing = company.bookkeeper_tasks.open_tasks
        .where(task_type: 'reconcile')
        .where("metadata->>'account_id' = ?", account.id.to_s)
        .exists?
      next if existing

      company.bookkeeper_tasks.create!(
        assigned_to: @user,
        task_type: 'reconcile',
        priority: 'normal',
        title: "Reconcile #{account.name}",
        description: last_recon ? "Last reconciled: #{last_recon.statement_date}" : "Never reconciled",
        estimated_minutes: 15,
        due_date: 5.days.from_now,
        metadata: { account_id: account.id, account_name: account.name }
      )
      created += 1
    end
    created
  end

  def generate_anomaly_tasks(company)
    anomalies = detect_anomalies(company)
    high = anomalies.select { |a| a[:severity] == 'high' }
    return 0 if high.empty?

    existing = company.bookkeeper_tasks.open_tasks.where(task_type: 'review_anomaly').exists?
    return 0 if existing

    company.bookkeeper_tasks.create!(
      assigned_to: @user,
      task_type: 'review_anomaly',
      priority: 'high',
      title: "#{high.size} anomalies detected",
      description: high.first(3).map { |a| a[:message] }.join("\n"),
      estimated_minutes: 10,
      due_date: 2.days.from_now,
      metadata: { anomalies: high.first(10) }
    )
    1
  end

  def generate_receipt_tasks(company)
    unmatched = company.receipts.unmatched.count
    return 0 if unmatched < 3

    existing = company.bookkeeper_tasks.open_tasks.where(task_type: 'receipt_match').exists?
    return 0 if existing

    company.bookkeeper_tasks.create!(
      assigned_to: @user,
      task_type: 'receipt_match',
      priority: 'low',
      title: "#{unmatched} unmatched receipts",
      description: "Review and match receipts to transactions",
      estimated_minutes: (unmatched * 2),
      due_date: 7.days.from_now
    )
    1
  end

  def generate_bank_health_tasks(company)
    last_txn = company.account_transactions.maximum(:date)
    return 0 unless last_txn
    days = (Date.current - last_txn).to_i
    return 0 if days < 14

    existing = company.bookkeeper_tasks.open_tasks.where(task_type: 'bank_reconnect').exists?
    return 0 if existing

    company.bookkeeper_tasks.create!(
      assigned_to: @user,
      task_type: 'bank_reconnect',
      priority: days > 30 ? 'critical' : 'high',
      title: "#{company.name}: No transactions in #{days} days",
      description: "Bank connection may be broken. Last transaction: #{last_txn}",
      estimated_minutes: 5,
      due_date: 1.day.from_now,
      metadata: { last_transaction_date: last_txn.to_s, days_stale: days }
    )
    1
  end

  def generate_month_end_tasks(company)
    # If it's past the 5th and last month isn't closed
    return 0 if Date.current.day < 5
    last_month = 1.month.ago.beginning_of_month.to_date

    close = MonthEndClose.find_by(company: company, period: last_month)
    return 0 if close&.status == 'closed'

    existing = company.bookkeeper_tasks.open_tasks.where(task_type: 'close_month').exists?
    return 0 if existing

    company.bookkeeper_tasks.create!(
      assigned_to: @user,
      task_type: 'close_month',
      priority: Date.current.day > 15 ? 'critical' : 'high',
      title: "Close #{last_month.strftime('%B %Y')}",
      description: "Month-end close is #{close ? "#{close.progress}% complete" : 'not started'}",
      estimated_minutes: 30,
      due_date: last_month.end_of_month + 15.days,
      metadata: { period: last_month.to_s }
    )
    1
  end

  def find_regular_transactions(company)
    # Find merchants that appear regularly (at least 3 times in 90 days)
    regulars = company.account_transactions
      .where(date: 90.days.ago..Date.current)
      .where.not(merchant_name: [nil, ''])
      .group(:merchant_name)
      .having('COUNT(*) >= 3')
      .pluck(:merchant_name)

    regulars.map do |merchant|
      txns = company.account_transactions
        .where(merchant_name: merchant)
        .where(date: 90.days.ago..Date.current)
        .order(date: :asc)

      dates = txns.pluck(:date)
      gaps = dates.each_cons(2).map { |a, b| (b - a).to_i }
      avg_gap = gaps.any? ? (gaps.sum.to_f / gaps.size).round(0) : nil

      next unless avg_gap && avg_gap.between?(5, 45)

      {
        description: merchant,
        frequency_days: avg_gap,
        avg_amount: txns.average(:amount).to_f.abs,
        last_date: dates.last
      }
    end.compact
  end
end
