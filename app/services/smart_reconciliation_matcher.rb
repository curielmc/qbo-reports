require 'net/http'
require 'json'

class SmartReconciliationMatcher
  def initialize(company)
    @company = company
  end

  # AI-powered reconciliation matching
  # Returns suggested transaction IDs with confidence scores
  def suggest_matches(reconciliation)
    target = reconciliation.statement_balance

    uncleared = reconciliation.account.account_transactions
      .where('date <= ?', reconciliation.statement_date)
      .where(reconciliation_status: 'uncleared')
      .order(date: :asc)

    return { suggested: [], projected_balance: 0, difference: target } if uncleared.empty?

    # First try algorithmic matching (faster, no API call needed)
    algorithmic = algorithmic_match(uncleared, target)

    # If algorithmic gets an exact match, use it
    if algorithmic[:difference].abs < 0.01
      return algorithmic
    end

    # Otherwise, use AI for smarter matching
    ai_match(uncleared, target, reconciliation)
  end

  private

  def algorithmic_match(uncleared, target)
    # Subset-sum approach: try to find combination that sums to target
    txns = uncleared.pluck(:id, :amount)

    # If all transactions sum to target, suggest all
    total = txns.sum { |_, amt| amt }
    if (total - target).abs < 0.01
      return {
        suggested: txns.map { |id, amt| { id: id, amount: amt, confidence: 95, reason: 'All transactions sum to statement balance' } },
        projected_balance: total,
        difference: 0
      }
    end

    # Try greedy approach - add transactions that bring us closer to target
    selected = []
    running = 0.0

    # Sort by date (most recent first) to prefer recent transactions
    sorted = txns.sort_by { |_, amt| -amt.abs }

    sorted.each do |id, amt|
      new_total = running + amt
      if (new_total - target).abs < (running - target).abs
        selected << { id: id, amount: amt, confidence: 70, reason: 'Algorithmic match' }
        running = new_total
      end
      break if (running - target).abs < 0.01
    end

    {
      suggested: selected,
      projected_balance: running.round(2),
      difference: (target - running).round(2)
    }
  end

  def ai_match(uncleared, target, reconciliation)
    txn_data = uncleared.limit(100).map do |t|
      {
        id: t.id,
        date: t.date.to_s,
        description: t.description,
        merchant: t.merchant_name,
        amount: t.amount.to_f,
        category: t.chart_of_account&.name
      }
    end

    # Get recently cleared transactions for pattern context
    recent_cleared = reconciliation.account.account_transactions
      .where(reconciliation_status: 'reconciled')
      .order(date: :desc)
      .limit(20)
      .pluck(:description, :amount, :date)
      .map { |d, a, dt| "#{d} | $#{a} | #{dt}" }

    prompt = <<~P
      You are an expert bookkeeper doing a bank reconciliation.

      TASK: Select which transactions should be marked as "cleared" to match the statement balance.

      Statement Balance: $#{target}
      Account: #{reconciliation.account.name}
      Statement Date: #{reconciliation.statement_date}

      UNCLEARED TRANSACTIONS:
      #{txn_data.map { |t| "ID:#{t[:id]} | #{t[:date]} | #{t[:description]} | #{t[:merchant]} | $#{t[:amount]}" }.join("\n")}

      RECENTLY RECONCILED (for context):
      #{recent_cleared.first(10).join("\n")}

      Select the transactions that most likely appear on the bank statement. Consider:
      1. Amount matching: the sum of selected transactions should equal $#{target}
      2. Date relevance: transactions before the statement date are more likely
      3. Transaction patterns: regular payments, deposits that match prior reconciliations
      4. Skip suspicious items: unusual amounts, very old transactions

      Return JSON:
      {
        "selected": [
          {
            "id": 123,
            "confidence": 95,
            "reason": "Regular monthly payment, matches prior pattern"
          }
        ],
        "notes": "Brief explanation of your matching strategy"
      }

      IMPORTANT: The sum of selected transaction amounts should be as close to $#{target} as possible.
    P

    response = call_ai(prompt)
    result = JSON.parse(response)
    selected_ids = (result['selected'] || []).map { |s| s['id'] }

    # Build response with full transaction data
    suggested = (result['selected'] || []).map do |s|
      txn = uncleared.find_by(id: s['id'])
      next unless txn
      {
        id: s['id'],
        amount: txn.amount.to_f,
        confidence: s['confidence'] || 80,
        reason: s['reason'] || 'AI suggested match'
      }
    end.compact

    projected = suggested.sum { |s| s[:amount] }

    {
      suggested: suggested,
      projected_balance: projected.round(2),
      difference: (target - projected).round(2),
      ai_notes: result['notes']
    }
  rescue => e
    Rails.logger.error "SmartReconciliationMatcher AI error: #{e.message}"
    # Fall back to algorithmic
    algorithmic_match(uncleared, target)
  end

  def call_ai(prompt)
    api_key = Rails.application.credentials.dig(:openai, :api_key) || ENV['OPENAI_API_KEY']
    return '{"selected":[]}' unless api_key

    uri = URI('https://api.openai.com/v1/chat/completions')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    body = {
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: 'You are an expert bookkeeper performing bank reconciliation. Select transactions that match the bank statement. Return ONLY valid JSON.' },
        { role: 'user', content: prompt }
      ],
      temperature: 0.1,
      max_tokens: 3000,
      response_format: { type: 'json_object' }
    }

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'
    request.body = body.to_json

    response = http.request(request)
    JSON.parse(response.body).dig('choices', 0, 'message', 'content') || '{"selected":[]}'
  end
end
