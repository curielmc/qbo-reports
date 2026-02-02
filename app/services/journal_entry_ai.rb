require 'net/http'
require 'json'

class JournalEntryAi
  def initialize(company, user = nil)
    @company = company
    @user = user
  end

  # ============================================
  # AI-GENERATED ADJUSTING ENTRIES
  # ============================================

  # Analyze the books and suggest all needed adjustments
  def suggest_adjustments(period_end = nil)
    period_end ||= Date.current.end_of_month
    period_start = period_end.beginning_of_month

    suggestions = []
    suggestions += suggest_depreciation(period_end)
    suggestions += suggest_prepaid_amortization(period_start, period_end)
    suggestions += suggest_accrued_expenses(period_start, period_end)
    suggestions += suggest_deferred_revenue(period_start, period_end)
    suggestions += suggest_unrecorded_liabilities(period_start, period_end)
    suggestions += suggest_reclassifications
    suggestions += suggest_from_ai_analysis(period_start, period_end)

    suggestions
  end

  # Auto-create all suggested adjustments (for month-end close)
  def auto_adjust(period_end = nil)
    suggestions = suggest_adjustments(period_end)
    created = []

    suggestions.each do |s|
      next if s[:confidence] < 80  # Only auto-create high confidence
      entry = create_from_suggestion(s)
      created << { id: entry.id, memo: entry.memo, total: entry.journal_lines.sum(:debit) } if entry
    end

    created
  end

  # ============================================
  # DEPRECIATION
  # ============================================

  def suggest_depreciation(period_end)
    suggestions = []

    # Find fixed asset accounts with balances
    asset_accounts = @company.chart_of_accounts.where(account_type: 'asset')
      .where('LOWER(name) LIKE ANY(ARRAY[?])', ['%equipment%', '%furniture%', '%vehicle%', '%computer%', '%machinery%', '%building%', '%fixed asset%', '%leasehold%'])

    asset_accounts.each do |asset_coa|
      balance = asset_coa.journal_lines.sum(:debit) - asset_coa.journal_lines.sum(:credit)
      next if balance <= 0

      # Check if depreciation was already recorded this month
      existing = @company.journal_entries
        .where(entry_type: 'depreciation')
        .where('memo LIKE ?', "%#{asset_coa.name}%")
        .where(entry_date: period_end.beginning_of_month..period_end)
        .exists?
      next if existing

      # Default: straight-line over 5 years (60 months)
      monthly_depreciation = (balance / 60.0).round(2)

      suggestions << {
        type: 'depreciation',
        confidence: 85,
        memo: "Monthly depreciation — #{asset_coa.name}",
        amount: monthly_depreciation,
        lines: [
          { account_name: 'Depreciation Expense', account_type: 'expense', side: 'debit' },
          { account_name: "Accumulated Depreciation — #{asset_coa.name}", account_type: 'asset', side: 'credit' }
        ],
        reasoning: "#{asset_coa.name} has a balance of $#{'%.2f' % balance}. Straight-line depreciation over 60 months = $#{'%.2f' % monthly_depreciation}/month.",
        entry_date: period_end
      }
    end

    suggestions
  end

  # ============================================
  # PREPAID EXPENSES
  # ============================================

  def suggest_prepaid_amortization(period_start, period_end)
    suggestions = []

    prepaid_accounts = @company.chart_of_accounts.where(account_type: 'asset')
      .where('LOWER(name) LIKE ANY(ARRAY[?])', ['%prepaid%', '%prepayment%', '%advance%'])

    prepaid_accounts.each do |prepaid_coa|
      balance = prepaid_coa.journal_lines.sum(:debit) - prepaid_coa.journal_lines.sum(:credit)
      next if balance <= 0

      # Check if already amortized this month
      existing = @company.journal_entries
        .where(entry_type: 'adjusting')
        .where('memo LIKE ?', "%#{prepaid_coa.name}%amortiz%")
        .where(entry_date: period_start..period_end)
        .exists?
      next if existing

      # Default: amortize over 12 months
      monthly_amount = (balance / 12.0).round(2)

      # Try to guess the expense category
      expense_name = prepaid_coa.name.gsub(/prepaid\s*/i, '').gsub(/prepayment\s*/i, '').strip
      expense_name = expense_name.present? ? expense_name : 'Prepaid Expenses'

      suggestions << {
        type: 'prepaid_amortization',
        confidence: 75,
        memo: "Prepaid amortization — #{prepaid_coa.name}",
        amount: monthly_amount,
        lines: [
          { account_name: expense_name, account_type: 'expense', side: 'debit' },
          { account_name: prepaid_coa.name, account_type: 'asset', side: 'credit' }
        ],
        reasoning: "#{prepaid_coa.name} has $#{'%.2f' % balance} remaining. Amortizing ~$#{'%.2f' % monthly_amount}/month.",
        entry_date: period_end
      }
    end

    suggestions
  end

  # ============================================
  # ACCRUED EXPENSES
  # ============================================

  def suggest_accrued_expenses(period_start, period_end)
    suggestions = []

    # Look for regular monthly expenses that haven't appeared this month
    regular_expenses = find_regular_monthly_expenses
    
    regular_expenses.each do |expense|
      # Check if this expense appeared this month
      this_month = @company.account_transactions
        .where(date: period_start..period_end)
        .where('LOWER(merchant_name) LIKE ? OR LOWER(description) LIKE ?',
          "%#{expense[:merchant].downcase}%", "%#{expense[:merchant].downcase}%")
        .exists?

      next if this_month

      # Check if already accrued
      already_accrued = @company.journal_entries
        .where(entry_type: 'accrual')
        .where('LOWER(memo) LIKE ?', "%#{expense[:merchant].downcase}%")
        .where(entry_date: period_start..period_end)
        .exists?
      next if already_accrued

      suggestions << {
        type: 'accrued_expense',
        confidence: 70,
        memo: "Accrued expense — #{expense[:merchant]} (expected ~$#{'%.2f' % expense[:avg_amount]})",
        amount: expense[:avg_amount].round(2),
        lines: [
          { account_name: expense[:category] || 'Miscellaneous', account_type: 'expense', side: 'debit' },
          { account_name: 'Accrued Liabilities', account_type: 'liability', side: 'credit' }
        ],
        reasoning: "#{expense[:merchant]} usually charges ~$#{'%.2f' % expense[:avg_amount]}/month but hasn't appeared this period. May need to be accrued.",
        entry_date: period_end
      }
    end

    suggestions
  end

  # ============================================
  # DEFERRED REVENUE
  # ============================================

  def suggest_deferred_revenue(period_start, period_end)
    suggestions = []

    deferred_accounts = @company.chart_of_accounts.where(account_type: 'liability')
      .where('LOWER(name) LIKE ANY(ARRAY[?])', ['%unearned%', '%deferred%', '%advance payment%', '%deposit%'])

    deferred_accounts.each do |deferred_coa|
      balance = deferred_coa.journal_lines.sum(:credit) - deferred_coa.journal_lines.sum(:debit)
      next if balance <= 0

      existing = @company.journal_entries
        .where(entry_type: 'adjusting')
        .where('memo LIKE ?', "%#{deferred_coa.name}%revenue recognition%")
        .where(entry_date: period_start..period_end)
        .exists?
      next if existing

      # Default: recognize 1/12 per month
      monthly_recognition = (balance / 12.0).round(2)

      suggestions << {
        type: 'revenue_recognition',
        confidence: 65,
        memo: "Revenue recognition — #{deferred_coa.name}",
        amount: monthly_recognition,
        lines: [
          { account_name: deferred_coa.name, account_type: 'liability', side: 'debit' },
          { account_name: 'Revenue', account_type: 'income', side: 'credit' }
        ],
        reasoning: "#{deferred_coa.name} has $#{'%.2f' % balance} in deferred revenue. Recognizing ~$#{'%.2f' % monthly_recognition}/month.",
        entry_date: period_end
      }
    end

    suggestions
  end

  # ============================================
  # UNRECORDED LIABILITIES
  # ============================================

  def suggest_unrecorded_liabilities(period_start, period_end)
    suggestions = []

    # Check for large deposits that might be loans
    large_deposits = @company.account_transactions
      .where(date: period_start..period_end)
      .where('amount > ?', 5000)
      .where(chart_of_account_id: nil)
      .where.not(merchant_name: [nil, ''])

    large_deposits.each do |txn|
      next if txn.description&.downcase&.include?('transfer')
      next if txn.merchant_name&.downcase&.include?('transfer')

      suggestions << {
        type: 'review_needed',
        confidence: 50,
        memo: "Review: Large uncategorized deposit — #{txn.merchant_name || txn.description} ($#{'%.2f' % txn.amount})",
        amount: txn.amount.abs,
        transaction_id: txn.id,
        lines: [],
        reasoning: "Large deposit of $#{'%.2f' % txn.amount} from #{txn.merchant_name || txn.description} on #{txn.date} is uncategorized. Could be revenue, loan proceeds, or owner contribution.",
        entry_date: txn.date
      }
    end

    suggestions
  end

  # ============================================
  # RECLASSIFICATIONS
  # ============================================

  def suggest_reclassifications
    suggestions = []

    # Negative expense balances (credits in expense accounts = wrong)
    @company.chart_of_accounts.where(account_type: 'expense').each do |coa|
      balance = coa.journal_lines.sum(:debit) - coa.journal_lines.sum(:credit)
      if balance < -100  # Significant negative balance
        suggestions << {
          type: 'reclassification',
          confidence: 80,
          memo: "Reclassify: #{coa.name} has negative balance ($#{'%.2f' % balance})",
          amount: balance.abs,
          lines: [
            { account_name: coa.name, account_type: 'expense', side: 'debit' },
            { account_name: 'Revenue', account_type: 'income', side: 'credit' }
          ],
          reasoning: "#{coa.name} has a credit balance of $#{'%.2f' % balance.abs}. Expense accounts shouldn't have credit balances — this may be a refund that should be reclassified as income.",
          entry_date: Date.current
        }
      end
    end

    suggestions
  end

  # ============================================
  # AI DEEP ANALYSIS
  # ============================================

  def suggest_from_ai_analysis(period_start, period_end)
    # Gather financial summary for AI
    income = @company.chart_of_accounts.where(account_type: 'income')
      .map { |c| { name: c.name, balance: c.journal_lines.sum(:credit) - c.journal_lines.sum(:debit) } }
      .select { |c| c[:balance] != 0 }

    expenses = @company.chart_of_accounts.where(account_type: 'expense')
      .map { |c| { name: c.name, balance: c.journal_lines.sum(:debit) - c.journal_lines.sum(:credit) } }
      .select { |c| c[:balance] != 0 }

    uncategorized_count = @company.account_transactions.where(chart_of_account_id: nil).count
    
    # Don't call AI if there's not much to analyze
    return [] if income.empty? && expenses.empty?

    prompt = <<~P
      Review this company's books for #{period_start.strftime('%B %Y')} and suggest adjusting journal entries.

      INCOME ACCOUNTS:
      #{income.map { |c| "#{c[:name]}: $#{'%.2f' % c[:balance]}" }.join("\n")}

      EXPENSE ACCOUNTS:
      #{expenses.map { |c| "#{c[:name]}: $#{'%.2f' % c[:balance]}" }.join("\n")}

      Uncategorized transactions: #{uncategorized_count}

      Look for:
      1. Missing common adjustments (depreciation, accruals, prepaids)
      2. Unusual balances or ratios
      3. Potential misclassifications
      4. Tax-related adjustments needed

      Return JSON array of suggestions:
      [{"type": "adjusting", "memo": "description", "amount": 0.00, "confidence": 0-100,
        "debit_account": "account name", "credit_account": "account name",
        "reasoning": "why this is needed"}]
      
      Only suggest entries with confidence >= 60. Return empty array if books look clean.
    P

    response = call_ai(prompt)
    begin
      ai_suggestions = JSON.parse(response)
      ai_suggestions = ai_suggestions.is_a?(Array) ? ai_suggestions : []
      
      ai_suggestions.map do |s|
        {
          type: s['type'] || 'adjusting',
          confidence: s['confidence'] || 60,
          memo: s['memo'],
          amount: s['amount'].to_f,
          lines: [
            { account_name: s['debit_account'], account_type: 'expense', side: 'debit' },
            { account_name: s['credit_account'], account_type: 'liability', side: 'credit' }
          ],
          reasoning: s['reasoning'],
          entry_date: period_end,
          source: 'ai_analysis'
        }
      end
    rescue
      []
    end
  end

  # ============================================
  # CREATE FROM SUGGESTION
  # ============================================

  def create_from_suggestion(suggestion)
    return nil if suggestion[:lines].blank? || suggestion[:amount] <= 0

    entry = @company.journal_entries.build(
      entry_date: suggestion[:entry_date] || Date.current,
      memo: suggestion[:memo],
      source: 'ai',
      entry_type: suggestion[:type] || 'adjusting',
      posted: false  # AI entries start as drafts for review
    )

    suggestion[:lines].each do |line|
      coa = find_or_create_account(line[:account_name], line[:account_type] || 'expense')
      next unless coa

      entry.journal_lines.build(
        chart_of_account: coa,
        debit: line[:side] == 'debit' ? suggestion[:amount] : 0,
        credit: line[:side] == 'credit' ? suggestion[:amount] : 0,
        memo: suggestion[:memo]
      )
    end

    entry.save ? entry : nil
  end

  private

  def find_or_create_account(name, account_type)
    return nil unless name.present?
    
    coa = @company.chart_of_accounts.find_by('LOWER(name) LIKE ?', "%#{name.downcase}%")
    return coa if coa

    # Create if it doesn't exist
    code = ChartOfAccountTemplates.next_code(@company, account_type)
    @company.chart_of_accounts.create!(
      name: name,
      account_type: account_type,
      code: code,
      active: true
    )
  end

  def find_regular_monthly_expenses
    # Find merchants that appear monthly (at least 2 of last 3 months)
    three_months_ago = 3.months.ago.to_date
    
    @company.account_transactions
      .where(date: three_months_ago..Date.current)
      .where('amount < 0')
      .where.not(merchant_name: [nil, ''])
      .where.not(chart_of_account_id: nil)
      .group(:merchant_name)
      .having('COUNT(DISTINCT date_trunc(\'month\', date)) >= 2')
      .select('merchant_name, AVG(ABS(amount)) as avg_amount, COUNT(*) as cnt')
      .map do |row|
        category = @company.account_transactions
          .where(merchant_name: row.merchant_name)
          .where.not(chart_of_account_id: nil)
          .last&.chart_of_account&.name

        {
          merchant: row.merchant_name,
          avg_amount: row.avg_amount.to_f,
          count: row.cnt,
          category: category
        }
      end
  end

  def call_ai(prompt)
    api_key = Rails.application.credentials.dig(:openai, :api_key) || ENV['OPENAI_API_KEY']
    return '[]' unless api_key

    uri = URI('https://api.openai.com/v1/chat/completions')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    body = {
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: 'You are a CPA specializing in adjusting journal entries. Return ONLY valid JSON.' },
        { role: 'user', content: prompt }
      ],
      temperature: 0.2,
      max_tokens: 3000,
      response_format: { type: 'json_object' }
    }

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'
    request.body = body.to_json

    response = http.request(request)
    JSON.parse(response.body).dig('choices', 0, 'message', 'content') || '[]'
  rescue => e
    Rails.logger.error "JournalEntryAi error: #{e.message}"
    '[]'
  end
end
