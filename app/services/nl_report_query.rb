require 'net/http'
require 'json'

class NlReportQuery
  def initialize(company)
    @company = company
  end

  # Process a natural language question about the company's finances
  # Returns structured data + text summary
  def query(question)
    # First, have AI determine what data we need
    plan = plan_query(question)
    return { text: plan['text'], data: nil } if plan['text'] && !plan['query_type']

    # Execute the planned query
    data = execute_query(plan)

    # Have AI summarize the results
    summary = summarize_results(question, plan, data)

    {
      text: summary,
      data: data,
      query_type: plan['query_type'],
      parameters: plan['parameters']
    }
  rescue => e
    Rails.logger.error "NlReportQuery error: #{e.message}"
    { text: "Sorry, I couldn't process that query. Try asking about spending, income, account balances, or comparisons between periods.", data: nil }
  end

  private

  def plan_query(question)
    categories = @company.chart_of_accounts.active.pluck(:name, :account_type)
    accounts = @company.accounts.active.pluck(:name, :account_type)

    prompt = <<~P
      You are a financial analyst. A user asks a question about their company's finances.
      Determine what query to run to answer their question.

      QUESTION: "#{question}"

      AVAILABLE CATEGORIES:
      #{categories.map { |n, t| "#{n} (#{t})" }.join(', ')}

      LINKED ACCOUNTS:
      #{accounts.map { |n, t| "#{n} (#{t})" }.join(', ')}

      TODAY: #{Date.current}

      AVAILABLE QUERY TYPES:
      1. spending_by_category - Total spending per expense category
         params: {start_date, end_date}
      2. income_by_category - Total income per income category
         params: {start_date, end_date}
      3. profit_loss - Net income (income - expenses)
         params: {start_date, end_date}
      4. category_detail - Detailed transactions for a specific category
         params: {category_name, start_date, end_date}
      5. trend - Monthly trend over time
         params: {months, category_name (optional)}
      6. compare_periods - Compare two time periods
         params: {period1_start, period1_end, period2_start, period2_end, period1_label, period2_label}
      7. top_vendors - Top vendors/merchants by spend
         params: {start_date, end_date, limit}
      8. account_balance - Current balance for a specific account
         params: {account_name}
      9. search - Search transactions by keyword
         params: {keyword, start_date, end_date, limit}
      10. balance_sheet - Current balance sheet summary
          params: {as_of_date}

      Return JSON:
      {
        "query_type": "one of the types above",
        "parameters": { ... },
        "explanation": "brief explanation of what you're querying"
      }

      If the question can't be answered with available queries, return:
      {"text": "helpful response explaining what you can answer"}

      IMPORTANT: Infer reasonable date ranges. "last month" means the previous calendar month.
      "last quarter" means the previous calendar quarter. "this year" means Jan 1 to today.
      "vs last year" means compare this year to the same period last year.
    P

    response = call_ai(prompt)
    JSON.parse(response)
  end

  def execute_query(plan)
    params = plan['parameters'] || {}

    case plan['query_type']
    when 'spending_by_category'
      spending_by_category(params)
    when 'income_by_category'
      income_by_category(params)
    when 'profit_loss'
      profit_loss(params)
    when 'category_detail'
      category_detail(params)
    when 'trend'
      trend(params)
    when 'compare_periods'
      compare_periods(params)
    when 'top_vendors'
      top_vendors(params)
    when 'account_balance'
      account_balance(params)
    when 'search'
      search_transactions(params)
    when 'balance_sheet'
      balance_sheet_summary(params)
    else
      { error: 'Unknown query type' }
    end
  end

  def spending_by_category(params)
    start_date = parse_date(params['start_date'], Date.current.beginning_of_year)
    end_date = parse_date(params['end_date'], Date.current)

    data = @company.chart_of_accounts.expense.active.map do |coa|
      amount = coa.period_balance(start_date: start_date, end_date: end_date)
      { name: coa.name, amount: amount.round(2) } if amount > 0
    end.compact.sort_by { |d| -d[:amount] }

    {
      type: 'spending_by_category',
      period: "#{start_date} to #{end_date}",
      items: data,
      total: data.sum { |d| d[:amount] }.round(2)
    }
  end

  def income_by_category(params)
    start_date = parse_date(params['start_date'], Date.current.beginning_of_year)
    end_date = parse_date(params['end_date'], Date.current)

    data = @company.chart_of_accounts.income.active.map do |coa|
      amount = coa.period_balance(start_date: start_date, end_date: end_date)
      { name: coa.name, amount: amount.round(2) } if amount > 0
    end.compact.sort_by { |d| -d[:amount] }

    {
      type: 'income_by_category',
      period: "#{start_date} to #{end_date}",
      items: data,
      total: data.sum { |d| d[:amount] }.round(2)
    }
  end

  def profit_loss(params)
    start_date = parse_date(params['start_date'], Date.current.beginning_of_year)
    end_date = parse_date(params['end_date'], Date.current)

    income = @company.chart_of_accounts.income.active.sum { |c| c.period_balance(start_date: start_date, end_date: end_date) }
    expenses = @company.chart_of_accounts.expense.active.sum { |c| c.period_balance(start_date: start_date, end_date: end_date) }

    {
      type: 'profit_loss',
      period: "#{start_date} to #{end_date}",
      income: income.round(2),
      expenses: expenses.round(2),
      net_income: (income - expenses).round(2)
    }
  end

  def category_detail(params)
    category_name = params['category_name']
    start_date = parse_date(params['start_date'], Date.current.beginning_of_year)
    end_date = parse_date(params['end_date'], Date.current)

    coa = @company.chart_of_accounts.find_by('LOWER(name) LIKE ?', "%#{category_name&.downcase}%")
    return { error: "Category '#{category_name}' not found" } unless coa

    lines = coa.journal_lines
      .joins(:journal_entry)
      .where(journal_entries: { entry_date: start_date..end_date, posted: true })
      .includes(journal_entry: :journal_lines)
      .order('journal_entries.entry_date ASC')

    transactions = lines.map do |line|
      je = line.journal_entry
      {
        date: je.entry_date,
        memo: je.memo,
        debit: line.debit.to_f,
        credit: line.credit.to_f,
        amount: (line.debit - line.credit).round(2)
      }
    end

    total = transactions.sum { |t| t[:amount] }

    {
      type: 'category_detail',
      category: coa.name,
      account_type: coa.account_type,
      period: "#{start_date} to #{end_date}",
      transactions: transactions,
      total: total.round(2),
      count: transactions.size
    }
  end

  def trend(params)
    months = (params['months'] || 6).to_i.clamp(1, 24)
    category_name = params['category_name']

    data = (0...months).map do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month

      if category_name
        coa = @company.chart_of_accounts.find_by('LOWER(name) LIKE ?', "%#{category_name.downcase}%")
        amount = coa ? coa.period_balance(start_date: month_start, end_date: month_end) : 0
      else
        amount = @company.chart_of_accounts.expense.active.sum { |c| c.period_balance(start_date: month_start, end_date: month_end) }
      end

      { month: month_start.strftime('%b %Y'), amount: amount.round(2) }
    end.reverse

    {
      type: 'trend',
      category: category_name || 'Total Expenses',
      months: months,
      data: data,
      average: (data.sum { |d| d[:amount] } / data.size.to_f).round(2)
    }
  end

  def compare_periods(params)
    p1_start = parse_date(params['period1_start'], 1.year.ago.beginning_of_year)
    p1_end = parse_date(params['period1_end'], 1.year.ago.end_of_year)
    p2_start = parse_date(params['period2_start'], Date.current.beginning_of_year)
    p2_end = parse_date(params['period2_end'], Date.current)

    p1_income = @company.chart_of_accounts.income.active.sum { |c| c.period_balance(start_date: p1_start, end_date: p1_end) }
    p1_expenses = @company.chart_of_accounts.expense.active.sum { |c| c.period_balance(start_date: p1_start, end_date: p1_end) }
    p2_income = @company.chart_of_accounts.income.active.sum { |c| c.period_balance(start_date: p2_start, end_date: p2_end) }
    p2_expenses = @company.chart_of_accounts.expense.active.sum { |c| c.period_balance(start_date: p2_start, end_date: p2_end) }

    # Category-level comparison
    expense_comparison = @company.chart_of_accounts.expense.active.map do |coa|
      p1 = coa.period_balance(start_date: p1_start, end_date: p1_end)
      p2 = coa.period_balance(start_date: p2_start, end_date: p2_end)
      change = p2 - p1
      pct = p1 > 0 ? ((change / p1) * 100).round(1) : 0
      { name: coa.name, period1: p1.round(2), period2: p2.round(2), change: change.round(2), pct: pct }
    end.select { |c| c[:period1] > 0 || c[:period2] > 0 }.sort_by { |c| -c[:change].abs }

    {
      type: 'compare_periods',
      period1: { label: params['period1_label'] || "#{p1_start} to #{p1_end}", income: p1_income.round(2), expenses: p1_expenses.round(2), net: (p1_income - p1_expenses).round(2) },
      period2: { label: params['period2_label'] || "#{p2_start} to #{p2_end}", income: p2_income.round(2), expenses: p2_expenses.round(2), net: (p2_income - p2_expenses).round(2) },
      changes: {
        income_change: (p2_income - p1_income).round(2),
        expense_change: (p2_expenses - p1_expenses).round(2),
        income_pct: p1_income > 0 ? ((p2_income - p1_income) / p1_income * 100).round(1) : 0,
        expense_pct: p1_expenses > 0 ? ((p2_expenses - p1_expenses) / p1_expenses * 100).round(1) : 0
      },
      expense_breakdown: expense_comparison.first(10)
    }
  end

  def top_vendors(params)
    start_date = parse_date(params['start_date'], Date.current.beginning_of_year)
    end_date = parse_date(params['end_date'], Date.current)
    limit = (params['limit'] || 10).to_i

    vendors = @company.account_transactions
      .where.not(merchant_name: [nil, ''])
      .where(date: start_date..end_date)
      .group(:merchant_name)
      .select('merchant_name, SUM(ABS(amount)) as total, COUNT(*) as txn_count')
      .order('total DESC')
      .limit(limit)
      .map { |v| { vendor: v.merchant_name, total: v.total.to_f.round(2), transactions: v.txn_count } }

    {
      type: 'top_vendors',
      period: "#{start_date} to #{end_date}",
      vendors: vendors,
      total: vendors.sum { |v| v[:total] }.round(2)
    }
  end

  def account_balance(params)
    account_name = params['account_name']
    account = @company.accounts.find_by('LOWER(name) LIKE ?', "%#{account_name&.downcase}%")

    if account
      {
        type: 'account_balance',
        account: account.name,
        account_type: account.account_type,
        balance: account.current_balance.to_f.round(2),
        last_synced: account.plaid_item&.last_synced_at
      }
    else
      # Try chart of accounts
      coa = @company.chart_of_accounts.find_by('LOWER(name) LIKE ?', "%#{account_name&.downcase}%")
      if coa
        balance = coa.period_balance(end_date: Date.current)
        { type: 'account_balance', account: coa.name, account_type: coa.account_type, balance: balance.round(2) }
      else
        { error: "Account '#{account_name}' not found" }
      end
    end
  end

  def search_transactions(params)
    keyword = params['keyword'] || ''
    start_date = parse_date(params['start_date'], Date.current.beginning_of_year)
    end_date = parse_date(params['end_date'], Date.current)
    limit = (params['limit'] || 20).to_i.clamp(1, 50)

    txns = @company.account_transactions
      .includes(:account, :chart_of_account)
      .where('description ILIKE ? OR merchant_name ILIKE ?', "%#{keyword}%", "%#{keyword}%")
      .where(date: start_date..end_date)
      .order(date: :desc)
      .limit(limit)
      .map do |t|
        { date: t.date, description: t.description, amount: t.amount.to_f, account: t.account&.name, category: t.chart_of_account&.name }
      end

    {
      type: 'search',
      keyword: keyword,
      period: "#{start_date} to #{end_date}",
      results: txns,
      count: txns.size,
      total: txns.sum { |t| t[:amount] }.round(2)
    }
  end

  def balance_sheet_summary(params)
    as_of = parse_date(params['as_of_date'], Date.current)

    assets = @company.chart_of_accounts.asset.active.map { |c| { name: c.name, balance: c.period_balance(end_date: as_of).round(2) } }.select { |a| a[:balance].abs > 0.01 }
    liabilities = @company.chart_of_accounts.liability.active.map { |c| { name: c.name, balance: c.period_balance(end_date: as_of).round(2) } }.select { |a| a[:balance].abs > 0.01 }
    equity = @company.chart_of_accounts.equity.active.map { |c| { name: c.name, balance: c.period_balance(end_date: as_of).round(2) } }.select { |a| a[:balance].abs > 0.01 }

    {
      type: 'balance_sheet',
      as_of: as_of,
      assets: { items: assets, total: assets.sum { |a| a[:balance] }.round(2) },
      liabilities: { items: liabilities, total: liabilities.sum { |a| a[:balance] }.round(2) },
      equity: { items: equity, total: equity.sum { |a| a[:balance] }.round(2) }
    }
  end

  def summarize_results(question, plan, data)
    prompt = <<~P
      A user asked: "#{question}"

      Query executed: #{plan['explanation']}
      Results: #{data.to_json}

      Provide a clear, concise answer to the user's question based on these results.
      Use $ formatting for currency. Include one key insight or observation.
      Keep it to 2-3 sentences maximum.
    P

    response = call_ai(prompt, system: 'You are a financial analyst answering questions about a company\'s finances. Be concise and use $ formatting. Return JSON: {"text": "your answer"}')
    result = JSON.parse(response)
    result['text'] || "Here are the results for your query."
  rescue
    "Here are the results for your query."
  end

  def parse_date(value, default)
    return default unless value.present?
    Date.parse(value.to_s)
  rescue
    default
  end

  def call_ai(prompt, system: nil)
    api_key = Rails.application.credentials.dig(:openai, :api_key) || ENV['OPENAI_API_KEY']
    return '{"text":"AI not configured"}' unless api_key

    uri = URI('https://api.openai.com/v1/chat/completions')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    body = {
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: system || 'You are a financial analyst. Determine the right query to answer the user\'s question. Return ONLY valid JSON.' },
        { role: 'user', content: prompt }
      ],
      temperature: 0.2,
      max_tokens: 2000,
      response_format: { type: 'json_object' }
    }

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'
    request.body = body.to_json

    response = http.request(request)
    JSON.parse(response.body).dig('choices', 0, 'message', 'content') || '{"text":"Sorry, I had trouble processing that."}'
  end
end
