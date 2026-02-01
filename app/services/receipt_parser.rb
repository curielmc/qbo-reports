require 'net/http'
require 'json'

class ReceiptParser
  def initialize(company)
    @company = company
  end

  # Parse a receipt image using GPT-4o vision
  def parse(file_url:, content_type: nil)
    prompt = <<~P
      Extract the following from this receipt image:
      - vendor: The business/store name
      - amount: Total amount paid (as a number, no currency symbol)
      - date: Date of purchase (YYYY-MM-DD format)
      - description: Brief description of what was purchased
      - items: Array of line items [{name, quantity, price}]
      - payment_method: How they paid (cash, credit card ending in XXXX, etc.)
      - tax_amount: Tax amount if visible
      - subtotal: Subtotal before tax if visible

      Return ONLY valid JSON.
    P

    response = call_vision_ai(prompt, file_url)
    begin
      data = JSON.parse(response)
      {
        vendor: data['vendor'],
        amount: data['amount']&.to_f,
        receipt_date: (Date.parse(data['date']) rescue nil),
        description: data['description'],
        items: data['items'],
        payment_method: data['payment_method'],
        tax_amount: data['tax_amount']&.to_f,
        subtotal: data['subtotal']&.to_f,
        raw_text: response
      }
    rescue
      { vendor: nil, amount: nil, receipt_date: nil, description: 'Could not parse receipt', raw_text: response }
    end
  end

  # Bulk parse: process all pending receipts
  def process_pending
    receipts = @company.receipts.pending
    results = []

    receipts.find_each do |receipt|
      parsed = parse(file_url: receipt.file_url, content_type: receipt.content_type)
      receipt.update!(
        vendor: parsed[:vendor],
        amount: parsed[:amount],
        receipt_date: parsed[:receipt_date],
        description: parsed[:description],
        raw_text: parsed[:raw_text],
        ai_data: parsed
      )
      receipt.auto_match!
      results << { id: receipt.id, vendor: parsed[:vendor], amount: parsed[:amount], status: receipt.status }
    end

    results
  end

  private

  def call_vision_ai(prompt, image_url)
    api_key = Rails.application.credentials.dig(:openai, :api_key) || ENV['OPENAI_API_KEY']
    return '{}' unless api_key

    uri = URI('https://api.openai.com/v1/chat/completions')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    messages = [
      { role: 'system', content: 'You are a receipt OCR expert. Extract data accurately. Return ONLY valid JSON.' },
      {
        role: 'user',
        content: [
          { type: 'text', text: prompt },
          { type: 'image_url', image_url: { url: image_url } }
        ]
      }
    ]

    body = {
      model: 'gpt-4o',
      messages: messages,
      temperature: 0.1,
      max_tokens: 1500,
      response_format: { type: 'json_object' }
    }

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'
    request.body = body.to_json

    response = http.request(request)
    JSON.parse(response.body).dig('choices', 0, 'message', 'content') || '{}'
  rescue => e
    Rails.logger.error "ReceiptParser AI error: #{e.message}"
    '{}'
  end
end
