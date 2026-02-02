class Api::V1::AgentController < ApplicationController
  before_action :authenticate_user!
  before_action :set_company

  # POST /api/v1/companies/:company_id/agent/process_statement
  def process_statement
    require_permission!('statements')
    return if performed?

    file = params[:file]
    unless file
      return render json: { error: 'No file provided. Send a PDF file as multipart form data.' }, status: :unprocessable_entity
    end

    file_content = file.read
    filename = file.original_filename

    service = StatementProcessingService.new(@company, current_user, api_key: current_api_key)
    result = service.process(
      file_content: file_content,
      filename: filename,
      account_id: params[:account_id],
      account_name: params[:account_name],
      statement_balance: params[:statement_balance],
      statement_date: params[:statement_date]&.to_date,
      parser: params[:parser]
    )

    status = if result[:success]
               :ok
             elsif result[:partial]
               207 # Multi-Status
             else
               :unprocessable_entity
             end

    render json: result, status: status
  end

  # GET /api/v1/companies/:company_id/agent/accounts
  def accounts
    accounts = @company.accounts.order(:name).map do |a|
      {
        id: a.id,
        name: a.name,
        account_type: a.account_type,
        current_balance: a.current_balance,
        transactions_count: a.account_transactions.count,
        last_reconciliation: @company.reconciliations
          .where(account_id: a.id)
          .order(statement_date: :desc)
          .first
          &.then { |r| { id: r.id, statement_date: r.statement_date, status: r.status, difference: r.difference } }
      }
    end

    render json: { accounts: accounts }
  end

  # GET /api/v1/companies/:company_id/agent/status
  def status
    recent_uploads = @company.statement_uploads
      .where(source: 'agent')
      .order(created_at: :desc)
      .limit(10)
      .map do |u|
        {
          id: u.id,
          filename: u.filename,
          status: u.status,
          transactions_found: u.transactions_found,
          transactions_imported: u.transactions_imported,
          parser_engine: u.parser_engine,
          created_at: u.created_at
        }
      end

    recent_recons = @company.reconciliations
      .where(source: 'agent')
      .order(created_at: :desc)
      .limit(10)
      .map do |r|
        {
          id: r.id,
          account_name: r.account.name,
          statement_date: r.statement_date,
          statement_balance: r.statement_balance,
          difference: r.difference,
          status: r.status,
          created_at: r.created_at
        }
      end

    render json: {
      recent_uploads: recent_uploads,
      recent_reconciliations: recent_recons
    }
  end

  private

  def set_company
    @company = resolve_company
    unless @company
      render json: { error: 'Company not found or not accessible' }, status: :not_found unless performed?
    end
  end
end
