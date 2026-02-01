require 'net/http'
require 'json'

class BookkeeperAi
  SYSTEM_PROMPT = <<~PROMPT
    You are ecfoBooks AI — a smart, efficient bookkeeper. You ARE the interface. Users talk to you to manage their entire bookkeeping.

    You have these actions. Return JSON with "action" and "params" to execute, or "text" for conversation.
    For multi-step work, return "actions" array.

    === CATEGORIZATION ===
    - categorize_transactions: {match_text, category_name} → categorize all matching uncategorized transactions
    - categorize_by_id: {transaction_ids, category_name} → categorize specific transactions by ID
    - suggest_categories: {} → AI looks at uncategorized transactions and suggests categories for each
    - auto_categorize: {} → run all existing rules on uncategorized transactions
    - show_uncategorized: {limit} → show uncategorized transactions needing review

    === RECONCILIATION ===
    - reconcile_account: {account_name} → compare bank balance vs book balance, flag discrepancies
    - show_pending: {account_name} → show pending/uncleared transactions
    - mark_cleared: {transaction_ids} → mark transactions as cleared
    - find_duplicates: {} → find potential duplicate transactions

    === ACCOUNTS & CATEGORIES ===
    - create_category: {name, account_type} → create new chart of account entry
    - rename_category: {old_name, new_name} → rename a category
    - list_categories: {type} → list categories by type (income/expense/asset/liability/equity)
    - merge_categories: {from_name, to_name} → merge one category into another

    === RULES ===
    - create_rule: {match_field, match_type, match_value, category_name, priority} → create auto-categorization rule
    - list_rules: {} → show all active rules
    - delete_rule: {rule_id} → delete a rule
    - suggest_rules: {} → suggest rules based on categorization patterns

    === QUERIES & REPORTS ===
    - spending_by_category: {start_date, end_date}
    - income_by_category: {start_date, end_date}
    - profit_loss: {start_date, end_date}
    - balance_summary: {}
    - search_transactions: {query, start_date, end_date, limit}
    - top_vendors: {start_date, end_date, limit}
    - monthly_trend: {months, category}
    - burn_rate: {}
    - anomalies: {days}
    - compare_periods: {period1_start, period1_end, period2_start, period2_end}

    === ACCOUNT MANAGEMENT ===
    - list_accounts: {} → show linked bank/credit accounts and balances
    - sync_account: {account_name} → trigger Plaid sync for an account
    - refresh_balances: {} → refresh all account balances

    === JOURNAL ENTRIES ===
    - create_adjustment: {lines, date, memo} → manual adjusting journal entry
    - show_journal: {start_date, end_date, account_name} → show journal entries

    Rules:
    - Default date range: current year (Jan 1 to today)
    - Be concise, use $ formatting, add insights
    - For categorization: show what you'll do, then do it
    - For bulk operations: show count and confirm
    - When suggesting categories, be specific and confident
    - Use emojis sparingly for readability
    - If ambiguous, ask ONE clarifying question
    - Never say "I can't do that" — find a way or suggest an alternative

    Return ONLY valid JSON:
    {"action": "action_name", "params": {...}}
    OR {"text": "response"}
    OR {"actions": [{"action": "...", "params": {...}}, ...]}
    OR {"confirm": "description of what I'll do", "action": "...", "params": {...}}
  PROMPT

  def initialize(company, user)
    @company = company
    @user = user
  end

  def chat(message, conversation_history = [])
    messages = [{ role: 'system', content: SYSTEM_PROMPT }]
    messages << { role: 'system', content: company_context }
    conversation_history.last(10).each do |msg|
      messages << { role: msg['role'] || msg[:role], content: msg['content'] || msg[:content] }
    end
    messages << { role: 'user', content: message }

    ai_response = call_ai(messages)

    begin
      decision = JSON.parse(ai_response)
    rescue JSON::ParserError
      return { text: ai_response, data: nil }
    end

    return { text: decision['text'], data: nil } if decision['text']

    # Confirmation flow — return the confirmation text, store the pending action
    if decision['confirm']
      return { text: decision['confirm'], data: nil, pending_action: { action: decision['action'], params: decision['params'] } }
    end

    # Execute action(s)
    if decision['actions']
      results = decision['actions'].map { |a| execute_action(a['action'], a['params'] || {}) }
      summary = summarize_results(message, results, messages)
      return { text: summary, data: results }
    elsif decision['action']
      result = execute_action(decision['action'], decision['params'] || {})
      summary = summarize_results(message, [result], messages)
      return { text: summary, data: [result] }
    end

    { text: "I'm not sure what you need. Try: \"categorize transactions\", \"show uncategorized\", \"reconcile Chase\", or ask me anything about your finances.", data: nil }
  end

  private

  def company_context
    accounts = @company.accounts.active.pluck(:name, :account_type, :current_balance, :mask)
    categories = @company.chart_of_accounts.active.pluck(:name, :account_type)
    uncategorized_count = @company.transactions.where(chart_of_account_id: nil).count
    rules_count = @company.categorization_rules.active.count
    pending_count = @company.transactions.pending.count

    recent_uncategorized = @company.transactions
      .where(chart_of_account_id: nil)
      .order(date: :desc)
      .limit(15)
      .pluck(:id, :date, :description, :amount, :merchant_name)
      .map { |id, d, desc, amt, merch| "ID:#{id} #{d} #{desc} $#{amt} #{merch}" }

    <<~CTX
      Company: #{@company.name}
      Today: #{Date.current}
      Year start: #{Date.current.beginning_of_year}

      Linked accounts (#{accounts.size}):
      #{accounts.map { |n, t, b, m| "  - #{n} (#{t}, ···#{m}): $#{'%.2f' % b}" }.join("\n")}

      Categories (#{categories.size}):
      #{categories.group_by(&:last).map { |type, cats| "  #{type}: #{cats.map(&:first).join(', ')}" }.join("\n")}

      Stats:
      - Uncategorized transactions: #{uncategorized_count}
      - Pending transactions: #{pending_count}
      - Active categorization rules: #{rules_count}

      Recent uncategorized transactions:
      #{recent_uncategorized.join("\n")}
    CTX
  end

  def execute_action(action, params)
    case action
    # Categorization
    when 'categorize_transactions' then categorize_transactions(params)
    when 'categorize_by_id' then categorize_by_id(params)
    when 'suggest_categories' then suggest_categories
    when 'auto_categorize' then auto_categorize
    when 'show_uncategorized' then show_uncategorized(params)
    # Reconciliation
    when 'reconcile_account' then reconcile_account(params)
    when 'show_pending' then show_pending(params)
    when 'mark_cleared' then mark_cleared(params)
    when 'find_duplicates' then find_duplicates
    # Accounts & Categories
    when 'create_category' then create_category(params)
    when 'rename_category' then rename_category(params)
    when 'list_categories' then list_categories(params)
    when 'merge_categories' then merge_categories(params)
    # Rules
    when 'create_rule' then create_rule(params)
    when 'list_rules' then list_rules
    when 'delete_rule' then delete_rule(params)
    when 'suggest_rules' then CategorizationRule.suggest_rules(@company)
    # Queries
    when 'spending_by_category' then spending_by_category(params)
    when 'income_by_category' then income_by_category(params)
    when 'profit_loss' then profit_loss(params)
    when 'balance_summary' then balance_summary
    when 'search_transactions' then search_transactions(params)
    when 'top_vendors' then top_vendors(params)
    when 'monthly_trend' then monthly_trend(params)
    when 'burn_rate' then burn_rate
    when 'anomalies' then anomalies(params)
    when 'compare_periods' then compare_periods(params)
    # Account management
    when 'list_accounts' then list_accounts
    when 'refresh_balances' then { action: 'refresh_balances', message: 'Triggered balance refresh for all accounts' }
    # Journal
    when 'create_adjustment' then create_adjustment(params)
    when 'show_journal' then show_journal(params)
    else
      { error: "Unknown action: #{action}" }
    end
  end

  # ============================================
  # CATEGORIZATION
  # ============================================

  def categorize_transactions(params)
    match_text = params['match_text']&.downcase
    category_name = params['category_name']
    return { error: 'Need match_text and category_name' } unless match_text && category_name

    coa = find_category(category_name)
    return { error: "Category '#{category_name}' not found. Available: #{available_categories}" } unless coa

    txns = @company.transactions
      .where(chart_of_account_id: nil)
      .where('LOWER(description) LIKE ? OR LOWER(merchant_name) LIKE ?', "%#{match_text}%", "%#{match_text}%")

    count = 0
    txns.find_each do |t|
      t.update!(chart_of_account_id: coa.id)
      count += 1
    end

    { action: 'categorize', match_text: match_text, category: coa.name, categorized: count }
  end

  def categorize_by_id(params)
    ids = params['transaction_ids'] || []
    category_name = params['category_name']
    return { error: 'Need transaction_ids and category_name' } unless ids.any? && category_name

    coa = find_category(category_name)
    return { error: "Category '#{category_name}' not found" } unless coa

    count = 0
    @company.transactions.where(id: ids).find_each do |t|
      t.update!(chart_of_account_id: coa.id)
      count += 1
    end

    { action: 'categorize_by_id', category: coa.name, categorized: count }
  end

  def suggest_categories
    uncategorized = @company.transactions
      .where(chart_of_account_id: nil)
      .order(date: :desc)
      .limit(20)

    return { action: 'suggest_categories', suggestions: [], message: 'No uncategorized transactions!' } if uncategorized.empty?

    # Use AI to suggest categories
    categories = @company.chart_of_accounts.active.pluck(:id, :name, :account_type)
    txn_data = uncategorized.map { |t| { id: t.id, description: t.description, amount: t.amount, merchant: t.merchant_name, date: t.date } }

    prompt = <<~P
      Suggest a category for each transaction. Available categories:
      #{categories.map { |id, name, type| "#{name} (#{type})" }.join(', ')}

      Transactions:
      #{txn_data.map { |t| "ID:#{t[:id]} - #{t[:description]} - $#{t[:amount]} - #{t[:merchant]} - #{t[:date]}" }.join("\n")}

      Return JSON array: [{"transaction_id": ID, "category_name": "name", "confidence": 0-100, "reason": "brief reason"}]
    P

    ai_suggestions = call_ai([
      { role: 'system', content: 'You are a bookkeeper. Suggest categories for transactions. Return ONLY a JSON array.' },
      { role: 'user', content: prompt }
    ])

    begin
      suggestions = JSON.parse(ai_suggestions)
      { action: 'suggest_categories', suggestions: suggestions }
    rescue
      { action: 'suggest_categories', suggestions: [], message: 'Could not generate suggestions' }
    end
  end

  def auto_categorize
    count = CategorizationRule.auto_categorize(@company)
    { action: 'auto_categorize', categorized: count }
  end

  def show_uncategorized(params)
    limit = (params['limit'] || 20).to_i
    txns = @company.transactions.includes(:account)
      .where(chart_of_account_id: nil)
      .order(date: :desc)
      .limit(limit)
      .map { |t| { id: t.id, date: t.date, description: t.description, amount: t.amount, account: t.account&.name, merchant: t.merchant_name } }

    total = @company.transactions.where(chart_of_account_id: nil).count
    { action: 'uncategorized', showing: txns.size, total: total, transactions: txns }
  end

  # ============================================
  # RECONCILIATION
  # ============================================

  def reconcile_account(params)
    account = find_account(params['account_name'])
    return { error: "Account '#{params['account_name']}' not found" } unless account

    bank_balance = account.current_balance
    book_balance = account.transactions.cleared.sum(:amount)
    pending_total = account.transactions.pending.sum(:amount)
    difference = bank_balance - book_balance

    uncleared = account.transactions.where(pending: false)
      .where('created_at > ?', 30.days.ago)
      .order(date: :desc)
      .limit(10)
      .map { |t| { id: t.id, date: t.date, description: t.description, amount: t.amount } }

    {
      action: 'reconcile',
      account: account.name,
      bank_balance: bank_balance,
      book_balance: book_balance,
      pending_total: pending_total,
      difference: difference,
      reconciled: difference.abs < 0.01,
      recent_transactions: uncleared
    }
  end

  def show_pending(params)
    account = find_account(params['account_name'])
    return { error: "Account not found" } unless account

    pending = account.transactions.pending.order(date: :desc)
      .map { |t| { id: t.id, date: t.date, description: t.description, amount: t.amount } }

    { action: 'pending', account: account.name, count: pending.size, transactions: pending }
  end

  def mark_cleared(params)
    ids = params['transaction_ids'] || []
    count = @company.transactions.where(id: ids).update_all(pending: false)
    { action: 'mark_cleared', cleared: count }
  end

  def find_duplicates
    # Find transactions with same amount, date, and similar description
    dupes = []
    @company.transactions.where(date: 90.days.ago..Date.current).group_by { |t| [t.date, t.amount.round(2)] }.each do |key, txns|
      next if txns.size < 2
      dupes << {
        date: key[0],
        amount: key[1],
        transactions: txns.map { |t| { id: t.id, description: t.description, account: t.account&.name } }
      }
    end

    { action: 'duplicates', count: dupes.size, duplicates: dupes.first(10) }
  end

  # ============================================
  # ACCOUNTS & CATEGORIES
  # ============================================

  def create_category(params)
    coa = @company.chart_of_accounts.build(
      name: params['name'],
      account_type: params['account_type'] || 'expense',
      active: true
    )
    if coa.save
      { action: 'create_category', name: coa.name, type: coa.account_type }
    else
      { error: coa.errors.full_messages.join(', ') }
    end
  end

  def rename_category(params)
    coa = find_category(params['old_name'])
    return { error: "Category '#{params['old_name']}' not found" } unless coa
    coa.update!(name: params['new_name'])
    { action: 'rename_category', old_name: params['old_name'], new_name: params['new_name'] }
  end

  def list_categories(params)
    cats = @company.chart_of_accounts.active
    cats = cats.where(account_type: params['type']) if params['type'].present?
    {
      action: 'list_categories',
      categories: cats.order(:account_type, :code).map { |c|
        { name: c.name, type: c.account_type, code: c.code, balance: c.balance }
      }
    }
  end

  def merge_categories(params)
    from = find_category(params['from_name'])
    to = find_category(params['to_name'])
    return { error: "Source category not found" } unless from
    return { error: "Target category not found" } unless to

    # Move all transactions
    moved = from.transactions.update_all(chart_of_account_id: to.id)
    # Rebuild journal entries for moved transactions
    to.transactions.find_each { |t| JournalEntry.from_transaction(t) }
    from.destroy if from.transactions.empty?

    { action: 'merge_categories', from: params['from_name'], to: params['to_name'], moved: moved }
  end

  # ============================================
  # RULES
  # ============================================

  def create_rule(params)
    coa = find_category(params['category_name'])
    return { error: "Category not found" } unless coa

    rule = @company.categorization_rules.create!(
      match_field: params['match_field'] || 'description',
      match_type: params['match_type'] || 'contains',
      match_value: params['match_value'],
      chart_of_account_id: coa.id,
      priority: params['priority'] || 0
    )
    { action: 'create_rule', rule_id: rule.id, match: "#{rule.match_field} #{rule.match_type} '#{rule.match_value}'", category: coa.name }
  end

  def list_rules
    rules = @company.categorization_rules.active.includes(:chart_of_account).by_priority
    {
      action: 'list_rules',
      rules: rules.map { |r|
        { id: r.id, field: r.match_field, type: r.match_type, pattern: r.match_value, category: r.chart_of_account&.name, applied: r.times_applied }
      }
    }
  end

  def delete_rule(params)
    rule = @company.categorization_rules.find(params['rule_id'])
    rule.destroy
    { action: 'delete_rule', rule_id: params['rule_id'] }
  end

  # ============================================
  # QUERIES
  # ============================================

  def spending_by_category(params)
    start_date = params['start_date'] || Date.current.beginning_of_year
    end_date = params['end_date'] || Date.current

    expenses = @company.chart_of_accounts.expense.active.map do |coa|
      amount = coa.period_balance(start_date: start_date, end_date: end_date)
      [coa.name, amount] if amount > 0
    end.compact.sort_by { |_, v| -v }

    { action: 'spending_by_category', period: "#{start_date} to #{end_date}", data: expenses.to_h, total: expenses.sum { |_, v| v } }
  end

  def income_by_category(params)
    start_date = params['start_date'] || Date.current.beginning_of_year
    end_date = params['end_date'] || Date.current

    income = @company.chart_of_accounts.income.active.map do |coa|
      amount = coa.period_balance(start_date: start_date, end_date: end_date)
      [coa.name, amount] if amount > 0
    end.compact.sort_by { |_, v| -v }

    { action: 'income_by_category', period: "#{start_date} to #{end_date}", data: income.to_h, total: income.sum { |_, v| v } }
  end

  def profit_loss(params)
    start_date = params['start_date'] || Date.current.beginning_of_year
    end_date = params['end_date'] || Date.current

    income = @company.chart_of_accounts.income.active.sum { |c| c.period_balance(start_date: start_date, end_date: end_date) }
    expenses = @company.chart_of_accounts.expense.active.sum { |c| c.period_balance(start_date: start_date, end_date: end_date) }

    { action: 'profit_loss', period: "#{start_date} to #{end_date}", income: income, expenses: expenses, net_income: income - expenses }
  end

  def balance_summary
    accounts = @company.accounts.active.map do |a|
      { name: a.name, type: a.account_type, balance: a.current_balance }
    end

    total_assets = accounts.select { |a| %w[checking savings depository investment brokerage].include?(a[:type]) }.sum { |a| a[:balance] }
    total_liabilities = accounts.select { |a| %w[credit credit_card loan mortgage].include?(a[:type]) }.sum { |a| a[:balance].abs }

    { action: 'balance_summary', accounts: accounts, total_assets: total_assets, total_liabilities: total_liabilities, net_worth: total_assets - total_liabilities }
  end

  def search_transactions(params)
    query = params['query'] || ''
    limit = (params['limit'] || 20).to_i.clamp(1, 50)

    txns = @company.transactions.includes(:account, :chart_of_account)
      .where('description ILIKE ? OR merchant_name ILIKE ?', "%#{query}%", "%#{query}%")
      .order(date: :desc)

    txns = txns.where('date >= ?', params['start_date']) if params['start_date']
    txns = txns.where('date <= ?', params['end_date']) if params['end_date']

    results = txns.limit(limit).map do |t|
      { id: t.id, date: t.date, description: t.description, amount: t.amount, account: t.account&.name, category: t.chart_of_account&.name }
    end

    { action: 'search_transactions', query: query, count: results.size, transactions: results }
  end

  def top_vendors(params)
    start_date = params['start_date'] || Date.current.beginning_of_year
    end_date = params['end_date'] || Date.current
    limit = (params['limit'] || 10).to_i

    vendors = @company.transactions
      .where.not(merchant_name: [nil, ''])
      .where(date: start_date..end_date, pending: false)
      .group(:merchant_name)
      .select('merchant_name, SUM(ABS(amount)) as total, COUNT(*) as txn_count')
      .order('total DESC')
      .limit(limit)
      .map { |v| { vendor: v.merchant_name, total: v.total.to_f, transactions: v.txn_count } }

    { action: 'top_vendors', period: "#{start_date} to #{end_date}", vendors: vendors }
  end

  def monthly_trend(params)
    months = (params['months'] || 6).to_i.clamp(1, 24)
    category_filter = params['category']

    data = (0...months).map do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month

      if category_filter
        coa = find_category(category_filter)
        amount = coa ? coa.period_balance(start_date: month_start, end_date: month_end) : 0
      else
        amount = @company.chart_of_accounts.expense.active.sum { |c| c.period_balance(start_date: month_start, end_date: month_end) }
      end

      { month: month_start.strftime('%b %Y'), amount: amount.round(2) }
    end.reverse

    { action: 'monthly_trend', months: months, category: category_filter || 'all expenses', data: data }
  end

  def burn_rate
    monthly_expenses = (0..2).map do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month
      @company.chart_of_accounts.expense.active.sum { |c| c.period_balance(start_date: month_start, end_date: month_end) }
    end

    avg_burn = monthly_expenses.sum / 3.0
    cash = @company.accounts.active.where(account_type: %w[checking savings depository]).sum(:current_balance)
    runway = avg_burn > 0 ? (cash / avg_burn).round(1) : nil

    { action: 'burn_rate', avg_monthly_burn: avg_burn.round(2), current_cash: cash, runway_months: runway }
  end

  def anomalies(params)
    days = (params['days'] || 30).to_i
    detector = AnomalyDetector.new(@company)
    { action: 'anomalies', alerts: detector.check_all }
  end

  def compare_periods(params)
    p1_income = @company.chart_of_accounts.income.active.sum { |c| c.period_balance(start_date: params['period1_start'], end_date: params['period1_end']) }
    p1_expenses = @company.chart_of_accounts.expense.active.sum { |c| c.period_balance(start_date: params['period1_start'], end_date: params['period1_end']) }
    p2_income = @company.chart_of_accounts.income.active.sum { |c| c.period_balance(start_date: params['period2_start'], end_date: params['period2_end']) }
    p2_expenses = @company.chart_of_accounts.expense.active.sum { |c| c.period_balance(start_date: params['period2_start'], end_date: params['period2_end']) }

    {
      action: 'compare_periods',
      period1: { income: p1_income, expenses: p1_expenses, net: p1_income - p1_expenses },
      period2: { income: p2_income, expenses: p2_expenses, net: p2_income - p2_expenses },
      changes: {
        income_change: p2_income - p1_income,
        expense_change: p2_expenses - p1_expenses,
        income_pct: p1_income > 0 ? ((p2_income - p1_income) / p1_income * 100).round(1) : 0,
        expense_pct: p1_expenses > 0 ? ((p2_expenses - p1_expenses) / p1_expenses * 100).round(1) : 0
      }
    }
  end

  # ============================================
  # ACCOUNT MANAGEMENT
  # ============================================

  def list_accounts
    accounts = @company.accounts.active.map { |a|
      { name: a.name, type: a.account_type, balance: a.current_balance, mask: a.mask, last_synced: a.plaid_item&.last_synced_at }
    }
    { action: 'list_accounts', accounts: accounts }
  end

  # ============================================
  # JOURNAL ENTRIES
  # ============================================

  def create_adjustment(params)
    lines = params['lines'] || []
    return { error: 'Need at least 2 journal lines' } if lines.size < 2

    begin
      entry = JournalEntry.create_adjustment(
        @company,
        lines.map { |l| { chart_of_account_id: find_category(l['account_name'])&.id, debit: l['debit'] || 0, credit: l['credit'] || 0, memo: l['memo'] } },
        params['date'] || Date.current,
        params['memo'] || 'Manual adjustment'
      )
      { action: 'create_adjustment', entry_id: entry.id, balanced: entry.balanced? }
    rescue => e
      { error: e.message }
    end
  end

  def show_journal(params)
    start_date = params['start_date'] || Date.current.beginning_of_year
    end_date = params['end_date'] || Date.current

    entries = @company.journal_entries.posted
      .where(entry_date: start_date..end_date)
      .includes(journal_lines: :chart_of_account)
      .order(entry_date: :desc)
      .limit(20)

    if params['account_name']
      coa = find_category(params['account_name'])
      entries = entries.joins(:journal_lines).where(journal_lines: { chart_of_account_id: coa&.id }).distinct if coa
    end

    {
      action: 'show_journal',
      entries: entries.map { |je|
        {
          date: je.entry_date, memo: je.memo, source: je.source,
          lines: je.journal_lines.map { |jl| { account: jl.chart_of_account.name, debit: jl.debit, credit: jl.credit } }
        }
      }
    }
  end

  # ============================================
  # HELPERS
  # ============================================

  def find_category(name)
    return nil unless name
    @company.chart_of_accounts.find_by('LOWER(name) = ?', name.downcase) ||
      @company.chart_of_accounts.find_by('LOWER(name) LIKE ?', "%#{name.downcase}%")
  end

  def find_account(name)
    return nil unless name
    @company.accounts.find_by('LOWER(name) LIKE ?', "%#{name.downcase}%")
  end

  def available_categories
    @company.chart_of_accounts.active.pluck(:name).join(', ')
  end

  def call_ai(messages)
    api_key = Rails.application.credentials.dig(:openai, :api_key) || ENV['OPENAI_API_KEY']
    return '{"text": "AI not configured. Set OPENAI_API_KEY to enable."}' unless api_key

    uri = URI('https://api.openai.com/v1/chat/completions')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    body = {
      model: Rails.application.credentials.dig(:openai, :model) || ENV['OPENAI_MODEL'] || 'gpt-4o-mini',
      messages: messages,
      temperature: 0.3,
      max_tokens: 2000,
      response_format: { type: 'json_object' }
    }

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'
    request.body = body.to_json

    response = http.request(request)
    result = JSON.parse(response.body)
    result.dig('choices', 0, 'message', 'content') || '{"text": "Sorry, I had trouble processing that."}'
  rescue => e
    Rails.logger.error "BookkeeperAi error: #{e.message}"
    '{"text": "Sorry, something went wrong. Please try again."}'
  end

  def summarize_results(question, results, original_messages)
    messages = original_messages + [
      { role: 'assistant', content: "Query results: #{results.to_json}" },
      { role: 'user', content: "Summarize these results in plain English, answering: '#{question}'. Be concise, use $ formatting, add one insight. Return JSON: {\"text\": \"your summary\"}" }
    ]

    response = call_ai(messages)
    begin
      JSON.parse(response)['text'] || response
    rescue
      response
    end
  end
end
