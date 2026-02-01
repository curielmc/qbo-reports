require 'net/http'
require 'json'

class BookkeeperAi
  SYSTEM_PROMPT = <<~PROMPT
    You are ecfoBooks AI — a smart, friendly bookkeeper assistant. You help users understand their finances through conversation.

    You have access to these FUNCTIONS to query the company's financial data. Return a JSON object with "action" and "params" to execute a query, or "text" for a direct response.

    Available actions:
    - spending_by_category: {start_date, end_date} → breakdown of expenses by category
    - income_by_category: {start_date, end_date} → breakdown of income by category  
    - profit_loss: {start_date, end_date} → P&L summary
    - balance_summary: {} → current account balances
    - search_transactions: {query, start_date, end_date, limit} → find specific transactions
    - uncategorized: {limit} → list uncategorized transactions
    - categorize: {match_text, category_name} → categorize transactions matching text
    - top_vendors: {start_date, end_date, limit} → biggest vendors by spend
    - monthly_trend: {months, category} → spending trend over N months
    - burn_rate: {} → monthly burn rate and runway estimate
    - anomalies: {days} → unusual transactions in last N days

    Rules:
    - Default date range is current year (Jan 1 to today) unless user specifies
    - Be concise but insightful — add context and observations
    - Use dollar formatting ($1,234.56)
    - If the user asks to DO something (categorize, etc), confirm what you'll do first
    - If you don't understand, ask for clarification
    - Be warm and professional, not robotic

    Respond with ONLY valid JSON:
    {"action": "action_name", "params": {...}} 
    OR
    {"text": "your response to the user"}
    OR for multi-step:
    {"actions": [{"action": "...", "params": {...}}, ...]}
  PROMPT

  def initialize(company, user)
    @company = company
    @user = user
  end

  # Main entry point: user sends a message, gets back a response
  def chat(message, conversation_history = [])
    # Build the AI request
    messages = [{ role: 'system', content: SYSTEM_PROMPT }]
    
    # Add context about the company
    messages << { role: 'system', content: company_context }
    
    # Add conversation history (last 10 messages)
    conversation_history.last(10).each do |msg|
      messages << { role: msg['role'] || msg[:role], content: msg['content'] || msg[:content] }
    end
    
    # Add the user's message
    messages << { role: 'user', content: message }

    # Call AI to interpret the message
    ai_response = call_ai(messages)
    
    # Parse AI decision
    begin
      decision = JSON.parse(ai_response)
    rescue JSON::ParserError
      # If AI returned plain text, use it directly
      return { text: ai_response, data: nil }
    end

    # If it's a direct text response
    if decision['text']
      return { text: decision['text'], data: nil }
    end

    # Execute the action(s)
    if decision['actions']
      results = decision['actions'].map { |a| execute_action(a['action'], a['params'] || {}) }
      # Ask AI to summarize the results
      summary = summarize_results(message, results, messages)
      return { text: summary, data: results }
    elsif decision['action']
      result = execute_action(decision['action'], decision['params'] || {})
      summary = summarize_results(message, [result], messages)
      return { text: summary, data: [result] }
    end

    { text: "I'm not sure how to help with that. Try asking about spending, income, transactions, or account balances.", data: nil }
  end

  private

  def company_context
    accounts = @company.accounts.active.pluck(:name, :account_type, :current_balance)
    categories = @company.chart_of_accounts.active.pluck(:name, :account_type)
    uncategorized_count = @company.transactions.where(chart_of_account_id: nil).count
    
    <<~CTX
      Company: #{@company.name}
      Accounts: #{accounts.map { |n, t, b| "#{n} (#{t}: $#{b})" }.join(', ')}
      Categories: #{categories.map { |n, t| "#{n} (#{t})" }.join(', ')}
      Uncategorized transactions: #{uncategorized_count}
      Today: #{Date.current}
      Year start: #{Date.current.beginning_of_year}
    CTX
  end

  def execute_action(action, params)
    case action
    when 'spending_by_category'
      spending_by_category(params)
    when 'income_by_category'
      income_by_category(params)
    when 'profit_loss'
      profit_loss(params)
    when 'balance_summary'
      balance_summary
    when 'search_transactions'
      search_transactions(params)
    when 'uncategorized'
      uncategorized(params)
    when 'categorize'
      categorize_transactions(params)
    when 'top_vendors'
      top_vendors(params)
    when 'monthly_trend'
      monthly_trend(params)
    when 'burn_rate'
      burn_rate
    when 'anomalies'
      anomalies(params)
    else
      { error: "Unknown action: #{action}" }
    end
  end

  # === ACTION IMPLEMENTATIONS ===

  def spending_by_category(params)
    start_date = params['start_date'] || Date.current.beginning_of_year
    end_date = params['end_date'] || Date.current

    expenses = @company.transactions
      .joins(:chart_of_account)
      .where(chart_of_accounts: { account_type: 'expense' })
      .where(date: start_date..end_date, pending: false)
      .group('chart_of_accounts.name')
      .sum(:amount)
      .transform_values(&:abs)
      .sort_by { |_, v| -v }

    { action: 'spending_by_category', period: "#{start_date} to #{end_date}", data: expenses.to_h, total: expenses.sum { |_, v| v } }
  end

  def income_by_category(params)
    start_date = params['start_date'] || Date.current.beginning_of_year
    end_date = params['end_date'] || Date.current

    income = @company.transactions
      .joins(:chart_of_account)
      .where(chart_of_accounts: { account_type: 'income' })
      .where(date: start_date..end_date, pending: false)
      .group('chart_of_accounts.name')
      .sum(:amount)
      .transform_values(&:abs)
      .sort_by { |_, v| -v }

    { action: 'income_by_category', period: "#{start_date} to #{end_date}", data: income.to_h, total: income.sum { |_, v| v } }
  end

  def profit_loss(params)
    start_date = params['start_date'] || Date.current.beginning_of_year
    end_date = params['end_date'] || Date.current

    income = @company.transactions
      .joins(:chart_of_account)
      .where(chart_of_accounts: { account_type: 'income' })
      .where(date: start_date..end_date, pending: false)
      .sum(:amount).abs

    expenses = @company.transactions
      .joins(:chart_of_account)
      .where(chart_of_accounts: { account_type: 'expense' })
      .where(date: start_date..end_date, pending: false)
      .sum(:amount).abs

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
    
    if params['start_date']
      txns = txns.where('date >= ?', params['start_date'])
    end
    if params['end_date']
      txns = txns.where('date <= ?', params['end_date'])
    end

    results = txns.limit(limit).map do |t|
      { date: t.date, description: t.description, amount: t.amount, account: t.account&.name, category: t.chart_of_account&.name }
    end

    { action: 'search_transactions', query: query, count: results.size, transactions: results }
  end

  def uncategorized(params)
    limit = (params['limit'] || 20).to_i
    txns = @company.transactions.includes(:account)
      .where(chart_of_account_id: nil)
      .order(date: :desc)
      .limit(limit)
      .map { |t| { id: t.id, date: t.date, description: t.description, amount: t.amount, account: t.account&.name, merchant: t.merchant_name } }

    total = @company.transactions.where(chart_of_account_id: nil).count
    { action: 'uncategorized', showing: txns.size, total: total, transactions: txns }
  end

  def categorize_transactions(params)
    match_text = params['match_text']&.downcase
    category_name = params['category_name']
    return { error: 'Need match_text and category_name' } unless match_text && category_name

    coa = @company.chart_of_accounts.find_by('LOWER(name) = ?', category_name.downcase)
    return { error: "Category '#{category_name}' not found" } unless coa

    count = @company.transactions
      .where(chart_of_account_id: nil)
      .where('LOWER(description) LIKE ? OR LOWER(merchant_name) LIKE ?', "%#{match_text}%", "%#{match_text}%")
      .update_all(chart_of_account_id: coa.id)

    { action: 'categorize', match_text: match_text, category: coa.name, categorized: count }
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

      txns = @company.transactions.joins(:chart_of_account)
        .where(date: month_start..month_end, pending: false)

      if category_filter
        txns = txns.where('chart_of_accounts.name ILIKE ?', "%#{category_filter}%")
      else
        txns = txns.where(chart_of_accounts: { account_type: 'expense' })
      end

      { month: month_start.strftime('%b %Y'), amount: txns.sum(:amount).abs }
    end.reverse

    { action: 'monthly_trend', months: months, category: category_filter || 'all expenses', data: data }
  end

  def burn_rate
    # Average monthly expenses over last 3 months
    monthly_expenses = (0..2).map do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month
      @company.transactions.joins(:chart_of_account)
        .where(chart_of_accounts: { account_type: 'expense' })
        .where(date: month_start..month_end, pending: false)
        .sum(:amount).abs
    end

    avg_burn = monthly_expenses.sum / 3.0

    # Current cash
    cash = @company.accounts.active
      .where(account_type: %w[checking savings depository])
      .sum(:current_balance)

    runway = avg_burn > 0 ? (cash / avg_burn).round(1) : nil

    { action: 'burn_rate', avg_monthly_burn: avg_burn.round(2), current_cash: cash, runway_months: runway, monthly_expenses: monthly_expenses }
  end

  def anomalies(params)
    days = (params['days'] || 30).to_i
    start_date = days.days.ago.to_date

    # Find transactions that are significantly different from average
    txns = @company.transactions.includes(:account, :chart_of_account)
      .where(date: start_date..Date.current)
      .where(pending: false)
      .order(Arel.sql('ABS(amount) DESC'))
      .limit(10)

    results = txns.map do |t|
      # Compare to average for this merchant
      avg = @company.transactions
        .where(merchant_name: t.merchant_name)
        .where.not(id: t.id)
        .average(:amount)&.abs

      {
        date: t.date,
        description: t.description,
        amount: t.amount,
        account: t.account&.name,
        category: t.chart_of_account&.name,
        merchant_avg: avg&.round(2),
        deviation: avg && avg > 0 ? ((t.amount.abs - avg) / avg * 100).round(0) : nil
      }
    end

    { action: 'anomalies', period: "last #{days} days", transactions: results }
  end

  # === AI CALLS ===

  def call_ai(messages)
    # Use OpenAI-compatible API (configurable)
    api_key = Rails.application.credentials.dig(:openai, :api_key) || ENV['OPENAI_API_KEY']
    return '{"text": "AI not configured. Set OPENAI_API_KEY to enable chat."}' unless api_key

    uri = URI('https://api.openai.com/v1/chat/completions')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    body = {
      model: 'gpt-4o-mini',
      messages: messages,
      temperature: 0.3,
      max_tokens: 1000,
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
      { role: 'assistant', content: "I executed the query and got these results: #{results.to_json}" },
      { role: 'user', content: "Now summarize these results in plain English, answering my original question: '#{question}'. Be concise, use dollar formatting, add observations or insights. Return JSON: {\"text\": \"your summary\"}" }
    ]

    response = call_ai(messages)
    begin
      JSON.parse(response)['text'] || response
    rescue
      response
    end
  end
end
