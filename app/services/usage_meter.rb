class UsageMeter
  def initialize(company, user)
    @company = company
    @user = user
  end

  # Record a query and deduct from credit
  def track(action, input_tokens: 0, output_tokens: 0, summary: nil)
    cost_cents = AiQuery.cost_for(action)
    
    # Use company's custom per-query rate if set, otherwise use defaults
    cost_cents = @company.per_query_cents if @company.per_query_cents > 0

    # Calculate actual AI cost (for internal tracking)
    actual_cost = estimate_ai_cost(input_tokens, output_tokens)

    query = @company.ai_queries.create!(
      user: @user,
      action: action,
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      cost: actual_cost,
      billed_amount: cost_cents / 100.0,
      query_summary: summary || action.humanize
    )

    # Deduct from credit
    @company.increment!(:ai_credit_used_cents, cost_cents)

    query
  end

  # Check if company has credit remaining
  def has_credit?
    @company.ai_credit_cents > @company.ai_credit_used_cents
  end

  # Remaining credit in dollars
  def credit_remaining
    ((@company.ai_credit_cents - @company.ai_credit_used_cents) / 100.0).round(2)
  end

  # Total used this billing cycle
  def cycle_usage
    start_date = @company.billing_cycle_start || Date.current.beginning_of_month
    queries = @company.ai_queries.this_cycle(start_date)
    
    {
      total_queries: queries.count,
      total_billed: queries.sum(:billed_amount).round(2),
      by_action: queries.group(:action).count,
      credit_total: @company.ai_credit_cents / 100.0,
      credit_used: @company.ai_credit_used_cents / 100.0,
      credit_remaining: credit_remaining,
      overage: [(@company.ai_credit_used_cents - @company.ai_credit_cents) / 100.0, 0].max.round(2)
    }
  end

  # Monthly summary for invoicing
  def billing_summary(month = nil)
    month ||= Date.current.beginning_of_month
    month_end = month.end_of_month

    queries = @company.ai_queries.where(created_at: month..month_end)

    base_fee = case @company.engagement_type
    when 'flat_fee' then @company.monthly_fee
    when 'hourly' then 0 # Calculated separately from time tracking
    else 0
    end

    credit = @company.ai_credit_cents / 100.0
    total_query_cost = queries.sum(:billed_amount).round(2)
    overage = [total_query_cost - credit, 0].max.round(2)

    {
      period: "#{month.strftime('%B %Y')}",
      company: @company.name,
      engagement_type: @company.engagement_type,
      base_fee: base_fee,
      ai_queries: queries.count,
      ai_query_cost: total_query_cost,
      ai_credit: credit,
      ai_overage: overage,
      total_due: base_fee + overage,
      breakdown: queries.group(:action)
        .select('action, COUNT(*) as count, SUM(billed_amount) as total')
        .map { |q| { action: q.action, count: q.count, total: q.total.round(2) } }
    }
  end

  private

  # Estimate actual OpenAI cost for internal margin tracking
  def estimate_ai_cost(input_tokens, output_tokens)
    # GPT-4o-mini pricing: $0.15/1M input, $0.60/1M output
    (input_tokens * 0.00000015 + output_tokens * 0.0000006).round(6)
  end
end
