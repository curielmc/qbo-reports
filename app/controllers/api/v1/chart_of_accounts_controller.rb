module Api
  module V1
    class ChartOfAccountsController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!
      before_action :set_company

      # GET /api/v1/companies/:company_id/chart_of_accounts
      def index
        coa = @company.chart_of_accounts.order(:account_type, :code)
        render json: coa.map { |c| serialize(c) }
      end

      # POST /api/v1/companies/:company_id/chart_of_accounts
      def create
        coa = @company.chart_of_accounts.build(coa_params)
        if coa.save
          render json: serialize(coa), status: :created
        else
          render json: { errors: coa.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/companies/:company_id/chart_of_accounts/:id
      def update
        coa = @company.chart_of_accounts.find(params[:id])
        if coa.update(coa_params)
          render json: serialize(coa)
        else
          render json: { errors: coa.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/companies/:company_id/chart_of_accounts/:id
      def destroy
        coa = @company.chart_of_accounts.find(params[:id])
        if coa.transactions.exists?
          render json: { error: 'Cannot delete account with transactions. Deactivate it instead.' }, status: :unprocessable_entity
        else
          coa.destroy
          render json: { message: 'Account deleted' }
        end
      end

      private

      def set_company
        @company = current_user.accessible_companies.find(params[:company_id])
      end

      def coa_params
        params.require(:chart_of_account).permit(:code, :name, :account_type, :parent_id, :active)
      end

      def serialize(c)
        {
          id: c.id,
          code: c.code,
          name: c.name,
          account_type: c.account_type,
          parent_id: c.parent_id,
          active: c.active,
          transactions_count: c.transactions.count,
          created_at: c.created_at
        }
      end
    end
  end
end
