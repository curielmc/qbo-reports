require 'net/http'
require 'json'

class ReportSummarizer
  def initialize(company)
    @company = company
  end

  def summarize_profit_loss(income_data, expense_data, start_date, end_date)
    total_income = income_data.values.sum
    total_expenses = expense_data.values.sum
    net = total_income - total_expenses

    prompt = <<~P
      Summarize this Profit & Loss report for "#{@company.name}" (#{start_date} to #{end_date}) in 2-3 sentences.
      Be specific with numbers, mention the top categories, and add one actionable insight.
      
      Income: #{income_data.map { |k, v| "#{k}: $#{v.round(2)}" }.join(', ')} (Total: $#{total_income.round(2)})
      Expenses: #{expense_data.map { |k, v| "#{k}: $#{v.round(2)}" }.join(', ')} (Total: $#{total_expenses.round(2)})
      Net Income: $#{net.round(2)}
    P

    call_ai(prompt)
  end

  def summarize_balance_sheet(assets, liabilities, equity)
    prompt = <<~P
      Summarize this Balance Sheet for "#{@company.name}" in 2-3 sentences.
      Mention net worth, liquidity, and one observation.
      
      Assets: #{assets.map { |k, v| "#{k}: $#{v.round(2)}" }.join(', ')}
      Liabilities: #{liabilities.map { |k, v| "#{k}: $#{v.round(2)}" }.join(', ')}
      Equity: #{equity.map { |k, v| "#{k}: $#{v.round(2)}" }.join(', ')}
    P

    call_ai(prompt)
  end

  private

  def call_ai(prompt)
    api_key = Rails.application.credentials.dig(:openai, :api_key) || ENV['OPENAI_API_KEY']
    return nil unless api_key

    uri = URI('https://api.openai.com/v1/chat/completions')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 15

    body = {
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: 'You are a concise financial analyst. Summarize reports in plain English. Be specific with dollar amounts. Use professional but accessible language. No bullet points — write flowing sentences.' },
        { role: 'user', content: prompt }
      ],
      temperature: 0.4,
      max_tokens: 300
    }

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'
    request.body = body.to_json

    response = http.request(request)
    result = JSON.parse(response.body)
    result.dig('choices', 0, 'message', 'content')
  rescue => e
    Rails.logger.error "ReportSummarizer error: #{e.message}"
    nil
  end
end
