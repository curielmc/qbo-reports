class ReconciliationService
  def initialize(company, user)
    @company = company
    @user = user
  end

  # Start a new reconciliation
  def start(account_id:, statement_date:, statement_balance:)
    account = @company.accounts.find(account_id)

    recon = @company.reconciliations.create!(
      account: account,
      user: @user,
      statement_date: statement_date,
      statement_balance: statement_balance,
      book_balance: 0,
      status: 'in_progress'
    )

    # Get unreconciled transactions up to statement date
    uncleared = account.account_transactions
      .where('date <= ?', statement_date)
      .where(reconciliation_status: 'uncleared')
      .order(date: :asc)

    {
      reconciliation: recon,
      uncleared_transactions: uncleared,
      statement_balance: statement_balance,
      uncleared_count: uncleared.count,
      uncleared_total: uncleared.sum(:amount)
    }
  end

  # Clear/unclear a transaction
  def toggle_cleared(reconciliation_id:, transaction_id:)
    recon = @company.reconciliations.find(reconciliation_id)
    txn = @company.account_transactions.find(transaction_id)

    if txn.reconciliation_status == 'cleared' && txn.reconciliation_id == recon.id
      txn.update!(reconciliation_status: 'uncleared', reconciliation_id: nil)
    else
      txn.update!(reconciliation_status: 'cleared', reconciliation_id: recon.id)
    end

    recon.recalculate!

    AuditLog.record!(
      company: @company, user: @user,
      action: 'toggle_cleared',
      resource: txn,
      changes: { reconciliation_status: txn.reconciliation_status }
    )

    {
      transaction_id: txn.id,
      status: txn.reconciliation_status,
      book_balance: recon.book_balance,
      difference: recon.difference,
      reconciliation_status: recon.status
    }
  end

  # Finalize reconciliation
  def finish(reconciliation_id:)
    recon = @company.reconciliations.find(reconciliation_id)
    recon.recalculate!

    if recon.difference.zero?
      # Mark all cleared transactions as reconciled (permanent)
      recon.cleared_transactions.update_all(reconciliation_status: 'reconciled')
      recon.update!(status: 'completed')

      AuditLog.record!(
        company: @company, user: @user,
        action: 'reconciliation_completed',
        resource: recon,
        changes: { cleared_count: recon.cleared_transactions.count }
      )

      { success: true, message: "Reconciliation complete! #{recon.account_transactions.count} transactions reconciled." }
    else
      { success: false, difference: recon.difference, message: "Difference of $#{recon.difference.abs}. Please review." }
    end
  end

  # AI-assisted: suggest which transactions to clear
  def suggest_clears(reconciliation_id:)
    recon = @company.reconciliations.find(reconciliation_id)
    target = recon.statement_balance

    uncleared = recon.account.account_transactions
      .where('date <= ?', recon.statement_date)
      .where(reconciliation_status: 'uncleared')
      .order(date: :asc)

    # Simple greedy: try to find a combination that sums to the target
    running = 0
    suggested = []

    uncleared.each do |txn|
      if (running + txn.amount - target).abs >= (running - target).abs
        # Adding this makes it worse — skip
        next
      end
      suggested << txn.id
      running += txn.amount
      break if running == target
    end

    # If simple doesn't work, just suggest all
    if (running - target).abs > 0.01 && uncleared.sum(:amount) == target
      suggested = uncleared.pluck(:id)
    end

    {
      suggested_transaction_ids: suggested,
      projected_balance: running,
      difference: (target - running).round(2)
    }
  end

  # Get reconciliation history for an account
  def history(account_id:)
    @company.reconciliations
      .where(account_id: account_id)
      .order(statement_date: :desc)
      .limit(12)
      .map { |r|
        {
          id: r.id,
          statement_date: r.statement_date,
          statement_balance: r.statement_balance,
          status: r.status,
          difference: r.difference,
          created_at: r.created_at
        }
      }
  end
end
