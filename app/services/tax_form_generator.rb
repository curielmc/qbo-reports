require 'net/http'
require 'json'

class TaxFormGenerator
  SUPPORTED_FORMS = {
    'schedule_c' => {
      name: 'Schedule C - Profit or Loss From Business',
      description: 'Sole proprietors and single-member LLCs',
      entity_types: %w[sole_proprietor single_member_llc]
    },
    'form_1065' => {
      name: 'Form 1065 - U.S. Return of Partnership Income',
      description: 'Partnerships and multi-member LLCs',
      entity_types: %w[partnership multi_member_llc]
    },
    'schedule_e' => {
      name: 'Schedule E - Supplemental Income and Loss',
      description: 'Rental real estate, royalties, partnerships, S corps',
      entity_types: %w[rental_property s_corp partnership]
    }
  }.freeze

  def initialize(company)
    @company = company
  end

  def supported_forms
    SUPPORTED_FORMS.map { |key, info| { id: key, name: info[:name], description: info[:description] } }
  end

  def generate(form_type, tax_year)
    return { error: "Unsupported form: #{form_type}" } unless SUPPORTED_FORMS.key?(form_type)

    # Gather financial data for the tax year
    start_date = Date.new(tax_year.to_i, 1, 1)
    end_date = Date.new(tax_year.to_i, 12, 31)

    financial_data = gather_financial_data(start_date, end_date)

    # Generate form via AI
    prompt = build_prompt(form_type, tax_year, financial_data)
    response = call_ai(prompt)
    result = JSON.parse(response)

    {
      form_type: form_type,
      form_name: SUPPORTED_FORMS[form_type][:name],
      tax_year: tax_year.to_i,
      company_name: @company.name,
      generated_at: Time.current.iso8601,
      account_mapping: result['account_mapping'] || [],
      sections: result['sections'] || [],
      totals: result['totals'] || {},
      notes: result['notes'] || [],
      disclaimer: 'This is an AI-generated draft for review purposes only. Consult a tax professional before filing.'
    }
  rescue => e
    Rails.logger.error "TaxFormGenerator error: #{e.message}"
    { error: "Failed to generate form: #{e.message}" }
  end

  private

  def gather_financial_data(start_date, end_date)
    lines = JournalLine.joins(journal_entry: [], chart_of_account: [])
      .where(journal_entries: { company_id: @company.id, posted: true })
      .where(journal_entries: { entry_date: start_date..end_date })

    income = {}
    expenses = {}
    assets = {}
    liabilities = {}

    @company.chart_of_accounts.active.each do |coa|
      coa_lines = lines.where(chart_of_account: coa)
      case coa.account_type
      when 'income'
        bal = coa_lines.sum(:credit) - coa_lines.sum(:debit)
        income[coa.name] = bal.round(2) if bal.abs > 0.01
      when 'expense'
        bal = coa_lines.sum(:debit) - coa_lines.sum(:credit)
        expenses[coa.name] = bal.round(2) if bal.abs > 0.01
      when 'asset'
        bal = coa_lines.sum(:debit) - coa_lines.sum(:credit)
        assets[coa.name] = bal.round(2) if bal.abs > 0.01
      when 'liability'
        bal = coa_lines.sum(:credit) - coa_lines.sum(:debit)
        liabilities[coa.name] = bal.round(2) if bal.abs > 0.01
      end
    end

    # Add Schedule C deductions (home office, vehicle)
    tax_year = start_date.year
    home_office = @company.home_office_records.find_by(tax_year: tax_year)
    vehicles = @company.vehicle_records.where(tax_year: tax_year)

    {
      income: income,
      expenses: expenses,
      assets: assets,
      liabilities: liabilities,
      total_income: income.values.sum.round(2),
      total_expenses: expenses.values.sum.round(2),
      net_income: (income.values.sum - expenses.values.sum).round(2),
      schedule_c_additions: {
        home_office_deduction: home_office&.deductible_amount&.to_f || 0,
        home_office_method: home_office&.method,
        vehicle_deductions: vehicles.sum(:deductible_amount).to_f,
        vehicle_count: vehicles.count
      }
    }
  end

  def build_prompt(form_type, tax_year, data)
    form_info = SUPPORTED_FORMS[form_type]

    <<~P
      Generate a #{form_info[:name]} for tax year #{tax_year} based on this financial data for "#{@company.name}".

      INCOME:
      #{data[:income].map { |k, v| "  #{k}: $#{v}" }.join("\n")}
      Total Income: $#{data[:total_income]}

      EXPENSES:
      #{data[:expenses].map { |k, v| "  #{k}: $#{v}" }.join("\n")}
      Total Expenses: $#{data[:total_expenses]}

      ASSETS:
      #{data[:assets].map { |k, v| "  #{k}: $#{v}" }.join("\n")}

      LIABILITIES:
      #{data[:liabilities].map { |k, v| "  #{k}: $#{v}" }.join("\n")}

      Net Income: $#{data[:net_income]}

      SCHEDULE C DEDUCTIONS (worksheets):
      #{schedule_c_additions_text(data[:schedule_c_additions])}

      #{form_specific_instructions(form_type)}

      IMPORTANT: You must explicitly map each of the company's Chart of Account entries to the corresponding tax form line.
      Include a "account_mapping" array that shows exactly how each company account maps to tax lines.

      Return JSON with this structure:
      {
        "account_mapping": [
          {
            "company_account": "Advertising & Marketing",
            "amount": 5000.00,
            "tax_line": "8",
            "tax_description": "Advertising"
          },
          {
            "company_account": "Revenue",
            "amount": 50000.00,
            "tax_line": "1",
            "tax_description": "Gross receipts or sales"
          }
        ],
        "sections": [
          {
            "title": "Section name (e.g. Part I - Income)",
            "lines": [
              { "line": "1", "description": "Gross receipts or sales", "amount": 50000.00 },
              { "line": "2", "description": "Returns and allowances", "amount": 0 }
            ]
          }
        ],
        "totals": {
          "total_income": 50000.00,
          "total_deductions": 30000.00,
          "net_profit_or_loss": 20000.00
        },
        "notes": [
          "Any important notes about how amounts were mapped or assumptions made"
        ]
      }

      Map EVERY company income and expense account to the correct tax form line. If multiple company accounts map to the same tax line, show each mapping separately.
      Use official IRS line numbers and descriptions. Fill in amounts where data is available, use 0 for lines with no applicable data.
      Include only sections that have non-zero amounts or are required fields.
    P
  end

  def schedule_c_additions_text(additions)
    return "  No additional Schedule C worksheets entered." if additions.nil?

    lines = []
    if additions[:home_office_deduction].to_f > 0
      method_text = additions[:home_office_method] == 'simplified' ? 'Simplified Method' : 'Regular Method (Form 8829)'
      lines << "  Home Office Deduction (#{method_text}): $#{additions[:home_office_deduction].round(2)}"
    end
    if additions[:vehicle_deductions].to_f > 0
      lines << "  Vehicle Expenses (#{additions[:vehicle_count]} vehicle#{'s' if additions[:vehicle_count] != 1}): $#{additions[:vehicle_deductions].round(2)}"
    end

    lines.empty? ? "  No additional deductions entered." : lines.join("\n")
  end

  def form_specific_instructions(form_type)
    case form_type
    when 'schedule_c'
      <<~I
        This is IRS Schedule C (Form 1040). Include:
        - Part I: Income (Lines 1-7)
        - Part II: Expenses (Lines 8-27)
        - Part III: Cost of Goods Sold (if applicable)
        - Part IV: Vehicle Information (if applicable)
        - Part V: Other Expenses (for categories that don't fit standard lines)
        Map expense categories to standard Schedule C lines (advertising, car expenses, commissions, insurance, interest, legal, office expense, rent, repairs, supplies, taxes, travel, meals, utilities, wages, other).

        IMPORTANT for Schedule C deductions from worksheets:
        - If Home Office Deduction is provided, include it on Line 30 (Expenses for business use of home). Note whether Form 8829 is needed (Regular method) or simplified method was used.
        - If Vehicle Expenses are provided, include them on Line 9 (Car and truck expenses).
        - These amounts from worksheets should be added to any existing amounts already in those expense categories.
      I
    when 'form_1065'
      <<~I
        This is IRS Form 1065. Include:
        - Page 1: Income (Lines 1a-8)
        - Page 1: Deductions (Lines 9-21)
        - Ordinary Business Income/Loss (Line 22)
        - Schedule K: Partners' Distributive Share Items
        Map income and expense categories to standard Form 1065 lines.
      I
    when 'schedule_e'
      <<~I
        This is IRS Schedule E (Form 1040). Include:
        - Part I: Income or Loss From Rental Real Estate and Royalties
        - Lines 3-4: Rents received, Royalties received
        - Lines 5-19: Expenses (advertising, auto/travel, cleaning, commissions, insurance, legal, management fees, mortgage interest, repairs, supplies, taxes, utilities, depreciation, other)
        - Line 21: Net rental income or loss
        Map income and expense categories to standard Schedule E lines.
      I
    end
  end

  def call_ai(prompt)
    api_key = Rails.application.credentials.dig(:openai, :api_key) || ENV['OPENAI_API_KEY']
    return '{"sections":[],"totals":{},"notes":["AI not configured"]}' unless api_key

    uri = URI('https://api.openai.com/v1/chat/completions')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 45

    body = {
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: 'You are an expert tax accountant and CPA. Generate accurate IRS tax form data based on financial records. Use official IRS line numbers and descriptions. Return ONLY valid JSON.' },
        { role: 'user', content: prompt }
      ],
      temperature: 0.2,
      max_tokens: 4000,
      response_format: { type: 'json_object' }
    }

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'
    request.body = body.to_json

    response = http.request(request)
    JSON.parse(response.body).dig('choices', 0, 'message', 'content') || '{"sections":[],"totals":{},"notes":[]}'
  end
end
