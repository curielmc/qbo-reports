require 'net/http'
require 'json'

class MonthEndAnalyzer
  def initialize(company)
    @company = company
  end

  # Analyze the books for a given period and generate an AI-powered checklist
  def analyze(period_end)
    period_start = period_end.beginning_of_month
    period_end = period_end.end_of_month

    # Gather diagnostics
    diagnostics = {
      uncategorized: uncategorized_check(period_start, period_end),
      reconciliation: reconciliation_check(period_start, period_end),
      anomalies: anomaly_check(period_start, period_end),
      journal_entries: journal_check(period_start, period_end),
      balance_sheet: balance_sheet_check(period_end),
      receipts: receipt_check(period_start, period_end),
      pl_summary: pl_summary(period_start, period_end)
    }

    # Build checklist from diagnostics + AI analysis
    checklist = build_checklist(diagnostics, period_start, period_end)

    {
      period: period_start.strftime('%B %Y'),
      period_start: period_start,
      period_end: period_end,
      diagnostics: diagnostics,
      checklist: checklist,
      health_score: calculate_health_score(diagnostics)
    }
  end

  private

  def uncategorized_check(period_start, period_end)
    count = @company.account_transactions
      .where(chart_of_account_id: nil)
      .where(date: period_start..period_end)
      .count

    total_amount = @company.account_transactions
      .where(chart_of_account_id: nil)
      .where(date: period_start..period_end)
      .sum('ABS(amount)')

    {
      count: count,
      total_amount: total_amount.round(2),
      status: count.zero? ? 'pass' : 'fail',
      message: count.zero? ? 'All transactions categorized' : "#{count} uncategorized transactions ($#{'%.2f' % total_amount})"
    }
  end

  def reconciliation_check(period_start, period_end)
    accounts = @company.accounts.active
    unreconciled = []

    accounts.each do |account|
      last_recon = @company.reconciliations
        .where(account: account, status: 'completed')
        .order(statement_date: :desc)
        .first

      if last_recon.nil? || last_recon.statement_date < period_start
        unreconciled << {
          account_name: account.name,
          account_type: account.account_type,
          last_reconciled: last_recon&.statement_date,
          days_since: last_recon ? (Date.current - last_recon.statement_date).to_i : nil
        }
      end
    end

    {
      total_accounts: accounts.count,
      unreconciled_count: unreconciled.size,
      unreconciled: unreconciled,
      status: unreconciled.empty? ? 'pass' : 'fail',
      message: unreconciled.empty? ? 'All accounts reconciled' : "#{unreconciled.size} account(s) not reconciled for this period"
    }
  end

  def anomaly_check(period_start, period_end)
    issues = []

    # Check for large individual transactions (top 5 by absolute value)
    large_txns = @company.account_transactions
      .where(date: period_start..period_end)
      .order(Arel.sql('ABS(amount) DESC'))
      .limit(5)
      .pluck(:description, :amount, :date)

    avg_amount = @company.account_transactions
      .where(date: period_start..period_end)
      .average('ABS(amount)').to_f

    large_txns.each do |desc, amount, date|
      if amount.abs > avg_amount * 5 && amount.abs > 500
        issues << {
          type: 'large_transaction',
          description: "Unusually large: #{desc} ($#{'%.2f' % amount}) on #{date}",
          severity: 'warning'
        }
      end
    end

    # Check for negative balances in asset accounts
    @company.chart_of_accounts.asset.active.each do |coa|
      balance = coa.period_balance(start_date: period_start, end_date: period_end)
      if balance < -1
        issues << {
          type: 'negative_asset',
          description: "#{coa.name} has negative balance ($#{'%.2f' % balance})",
          severity: 'error'
        }
      end
    end

    # Check for negative expense accounts (credits > debits)
    @company.chart_of_accounts.expense.active.each do |coa|
      balance = coa.period_balance(start_date: period_start, end_date: period_end)
      if balance < -1
        issues << {
          type: 'negative_expense',
          description: "#{coa.name} has credit balance ($#{'%.2f' % balance}) — may need reclassification",
          severity: 'warning'
        }
      end
    end

    {
      count: issues.size,
      issues: issues,
      status: issues.empty? ? 'pass' : (issues.any? { |i| i[:severity] == 'error' } ? 'fail' : 'warning'),
      message: issues.empty? ? 'No anomalies detected' : "#{issues.size} issue(s) found"
    }
  end

  def journal_check(period_start, period_end)
    total_entries = @company.journal_entries
      .where(entry_date: period_start..period_end, posted: true)
      .count

    adjusting = @company.journal_entries
      .where(entry_date: period_start..period_end, entry_type: 'adjusting', posted: true)
      .count

    unbalanced = @company.journal_entries
      .where(entry_date: period_start..period_end, posted: true)
      .select { |je| !je.balanced? }
      .size

    draft = @company.journal_entries
      .where(entry_date: period_start..period_end, posted: false)
      .count

    {
      total: total_entries,
      adjusting: adjusting,
      unbalanced: unbalanced,
      draft: draft,
      status: unbalanced > 0 ? 'fail' : (draft > 0 ? 'warning' : 'pass'),
      message: [
        "#{total_entries} entries (#{adjusting} adjusting)",
        unbalanced > 0 ? "#{unbalanced} unbalanced!" : nil,
        draft > 0 ? "#{draft} draft entries not posted" : nil
      ].compact.join('; ')
    }
  end

  def balance_sheet_check(period_end)
    assets = @company.chart_of_accounts.asset.active.sum { |c| c.period_balance(end_date: period_end) }
    liabilities = @company.chart_of_accounts.liability.active.sum { |c| c.period_balance(end_date: period_end) }
    equity = @company.chart_of_accounts.equity.active.sum { |c| c.period_balance(end_date: period_end) }

    income = @company.chart_of_accounts.income.active.sum { |c| c.period_balance(start_date: period_end.beginning_of_year, end_date: period_end) }
    expenses = @company.chart_of_accounts.expense.active.sum { |c| c.period_balance(start_date: period_end.beginning_of_year, end_date: period_end) }
    retained = income - expenses

    total_equity = equity + retained
    difference = (assets - liabilities - total_equity).round(2)
    balanced = difference.abs < 0.01

    {
      assets: assets.round(2),
      liabilities: liabilities.round(2),
      equity: total_equity.round(2),
      difference: difference,
      balanced: balanced,
      status: balanced ? 'pass' : 'fail',
      message: balanced ? 'Balance sheet is balanced' : "Balance sheet off by $#{'%.2f' % difference.abs}"
    }
  end

  def receipt_check(period_start, period_end)
    unmatched = @company.receipts
      .where(status: 'unmatched')
      .where(receipt_date: period_start..period_end)
      .count rescue 0

    {
      unmatched: unmatched,
      status: unmatched.zero? ? 'pass' : 'warning',
      message: unmatched.zero? ? 'All receipts matched' : "#{unmatched} unmatched receipt(s)"
    }
  end

  def pl_summary(period_start, period_end)
    income = @company.chart_of_accounts.income.active.sum { |c| c.period_balance(start_date: period_start, end_date: period_end) }
    expenses = @company.chart_of_accounts.expense.active.sum { |c| c.period_balance(start_date: period_start, end_date: period_end) }

    {
      income: income.round(2),
      expenses: expenses.round(2),
      net_income: (income - expenses).round(2)
    }
  end

  def build_checklist(diagnostics, period_start, period_end)
    items = []

    # 1. Categorize all transactions
    d = diagnostics[:uncategorized]
    items << {
      key: 'categorize_all',
      label: d[:status] == 'pass' ? 'All transactions categorized' : "Categorize #{d[:count]} uncategorized transactions ($#{'%.2f' % d[:total_amount]})",
      status: d[:status],
      auto_fixable: d[:count] > 0,
      fix_action: 'auto_categorize',
      details: d[:message]
    }

    # 2. Reconcile bank accounts
    d = diagnostics[:reconciliation]
    if d[:unreconciled].any?
      d[:unreconciled].each do |acct|
        items << {
          key: "reconcile_#{acct[:account_name].parameterize.underscore}",
          label: "Reconcile #{acct[:account_name]}#{acct[:last_reconciled] ? " (last: #{acct[:last_reconciled]})" : ' (never reconciled)'}",
          status: 'fail',
          auto_fixable: false,
          fix_action: 'navigate_reconciliation',
          details: "#{acct[:account_type]} account needs reconciliation"
        }
      end
    else
      items << {
        key: 'reconcile_all',
        label: 'All bank accounts reconciled',
        status: 'pass',
        auto_fixable: false,
        details: "#{d[:total_accounts]} accounts checked"
      }
    end

    # 3. Review anomalies
    d = diagnostics[:anomalies]
    items << {
      key: 'review_anomalies',
      label: d[:status] == 'pass' ? 'No anomalies to review' : "Review #{d[:count]} anomal#{d[:count] == 1 ? 'y' : 'ies'}",
      status: d[:status],
      auto_fixable: false,
      details: d[:issues].map { |i| i[:description] }.first(3).join('; ')
    }

    # 4. Post draft journal entries
    d = diagnostics[:journal_entries]
    if d[:draft] > 0
      items << {
        key: 'post_drafts',
        label: "Post #{d[:draft]} draft journal entr#{d[:draft] == 1 ? 'y' : 'ies'}",
        status: 'warning',
        auto_fixable: false,
        fix_action: 'navigate_journal',
        details: 'Draft entries should be reviewed and posted'
      }
    end

    if d[:unbalanced] > 0
      items << {
        key: 'fix_unbalanced',
        label: "Fix #{d[:unbalanced]} unbalanced journal entr#{d[:unbalanced] == 1 ? 'y' : 'ies'}",
        status: 'fail',
        auto_fixable: false,
        fix_action: 'navigate_journal',
        details: 'Unbalanced entries must be corrected'
      }
    end

    # 5. Match receipts
    d = diagnostics[:receipts]
    if d[:unmatched] > 0
      items << {
        key: 'match_receipts',
        label: "Match #{d[:unmatched]} unmatched receipt(s)",
        status: 'warning',
        auto_fixable: false,
        fix_action: 'navigate_receipts',
        details: d[:message]
      }
    end

    # 6. Balance sheet check
    d = diagnostics[:balance_sheet]
    items << {
      key: 'balance_sheet_balanced',
      label: d[:balanced] ? 'Balance sheet is balanced' : "Balance sheet off by $#{'%.2f' % d[:difference].abs}",
      status: d[:status],
      auto_fixable: false,
      details: "A: $#{'%.2f' % d[:assets]} L: $#{'%.2f' % d[:liabilities]} E: $#{'%.2f' % d[:equity]}"
    }

    # 7. Review P&L
    pl = diagnostics[:pl_summary]
    items << {
      key: 'review_pl',
      label: "Review P&L: Net income $#{'%.2f' % pl[:net_income]}",
      status: 'info',
      auto_fixable: false,
      details: "Income: $#{'%.2f' % pl[:income]}, Expenses: $#{'%.2f' % pl[:expenses]}"
    }

    # 8. AI-generated additional checks
    ai_items = ai_additional_checks(diagnostics, period_start, period_end)
    items.concat(ai_items)

    items
  end

  def ai_additional_checks(diagnostics, period_start, period_end)
    prompt = <<~P
      You are a senior bookkeeper reviewing a company's month-end close for #{period_start.strftime('%B %Y')}.

      DIAGNOSTICS:
      #{JSON.pretty_generate(diagnostics)}

      Based on this data, suggest 2-4 additional month-end review items that a bookkeeper should check.
      Focus on items NOT already covered by the diagnostics (which handle: uncategorized txns, reconciliation, anomalies, journal entries, receipts, balance sheet balance, P&L review).

      Examples: accrual reviews, depreciation checks, payroll verification, sales tax review, prepaid expense amortization, etc.

      Return JSON:
      {
        "items": [
          {
            "key": "unique_key",
            "label": "Clear description of what to check",
            "details": "Why this matters for this specific company"
          }
        ]
      }
    P

    response = call_ai(prompt)
    result = JSON.parse(response)
    (result['items'] || []).map do |item|
      {
        key: item['key'],
        label: item['label'],
        status: 'info',
        auto_fixable: false,
        details: item['details']
      }
    end
  rescue => e
    Rails.logger.error "MonthEndAnalyzer AI error: #{e.message}"
    []
  end

  def calculate_health_score(diagnostics)
    score = 100

    # Deductions
    score -= [diagnostics[:uncategorized][:count] * 2, 30].min
    score -= diagnostics[:reconciliation][:unreconciled_count] * 10
    score -= diagnostics[:anomalies][:count] * 5
    score -= diagnostics[:journal_entries][:unbalanced] * 15
    score -= diagnostics[:journal_entries][:draft] * 3
    score -= diagnostics[:balance_sheet][:balanced] ? 0 : 20
    score -= [diagnostics.dig(:receipts, :unmatched).to_i * 2, 10].min

    [score, 0].max
  end

  def call_ai(prompt)
    api_key = Rails.application.credentials.dig(:openai, :api_key) || ENV['OPENAI_API_KEY']
    return '{"items":[]}' unless api_key

    uri = URI('https://api.openai.com/v1/chat/completions')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    body = {
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: 'You are an expert bookkeeper. Analyze the diagnostics and suggest additional month-end review items. Return ONLY valid JSON.' },
        { role: 'user', content: prompt }
      ],
      temperature: 0.3,
      max_tokens: 1500,
      response_format: { type: 'json_object' }
    }

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'
    request.body = body.to_json

    response = http.request(request)
    JSON.parse(response.body).dig('choices', 0, 'message', 'content') || '{"items":[]}'
  end
end
