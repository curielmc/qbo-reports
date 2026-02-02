require 'net/http'
require 'json'

class CoaSuggester
  def initialize(company)
    @company = company
  end

  def suggest(description)
    existing = @company.chart_of_accounts.active.pluck(:code, :name, :account_type)

    prompt = <<~P
      A user is setting up a Chart of Accounts for their company. Here is their description:
      "#{description}"

      Their existing Chart of Accounts:
      #{existing.map { |code, name, type| "#{code} - #{name} (#{type})" }.join("\n")}

      Based on the type of business described, suggest additional Chart of Account entries they should add.
      Consider industry-specific accounts, common tax-deductible categories, and best practices.
      Do NOT suggest accounts that already exist (check names carefully).
      Use appropriate account codes following the numbering convention: 1xxx=asset, 2xxx=liability, 3xxx=equity, 4xxx=income, 5xxx-6xxx=expense.

      Return JSON:
      {
        "suggestions": [
          {
            "code": "6200",
            "name": "Account Name",
            "account_type": "expense",
            "reason": "Brief reason why this account is relevant"
          }
        ]
      }

      Suggest 8-15 accounts that are most relevant to this specific business type. Be specific to the industry, not generic.
    P

    response = call_ai(prompt)
    result = JSON.parse(response)
    (result['suggestions'] || []).map do |s|
      {
        code: s['code'],
        name: s['name'],
        account_type: s['account_type'],
        reason: s['reason']
      }
    end
  rescue => e
    Rails.logger.error "CoaSuggester error: #{e.message}"
    []
  end

  private

  def call_ai(prompt)
    api_key = Rails.application.credentials.dig(:openai, :api_key) || ENV['OPENAI_API_KEY']
    return '{"suggestions":[]}' unless api_key

    uri = URI('https://api.openai.com/v1/chat/completions')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    body = {
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: 'You are an expert bookkeeper and CPA who specializes in setting up Chart of Accounts for different business types. Return ONLY valid JSON.' },
        { role: 'user', content: prompt }
      ],
      temperature: 0.3,
      max_tokens: 2000,
      response_format: { type: 'json_object' }
    }

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'
    request.body = body.to_json

    response = http.request(request)
    JSON.parse(response.body).dig('choices', 0, 'message', 'content') || '{"suggestions":[]}'
  end
end
