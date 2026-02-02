module Api
  module V1
    class AccountsController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!
      before_action :set_company

      # GET /api/v1/companies/:company_id/accounts
      def index
        accounts = @company.accounts.order(:name)
        render json: accounts.map { |a| serialize(a) }
      end

      # POST /api/v1/companies/:company_id/accounts
      def create
        account = @company.accounts.build(account_params)
        if account.save
          render json: serialize(account), status: :created
        else
          render json: { errors: account.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/companies/:company_id/accounts/:id
      def update
        account = @company.accounts.find(params[:id])
        if account.update(account_params)
          render json: serialize(account)
        else
          render json: { errors: account.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/companies/:company_id/accounts/:id
      def destroy
        account = @company.accounts.find(params[:id])
        account.destroy
        render json: { message: 'Account deleted' }
      end

      private

      def set_company
        @company = current_user.accessible_companies.find(params[:company_id])
      end

      def account_params
        params.require(:account).permit(:name, :institution, :account_type, :mask, :active)
      end

      def serialize(a)
        {
          id: a.id,
          name: a.name,
          official_name: a.official_name,
          account_type: a.account_type,
          mask: a.mask,
          current_balance: a.current_balance,
          available_balance: a.available_balance,
          active: a.active,
          plaid_linked: a.plaid_account_id.present?,
          created_at: a.created_at
        }
      end
    end
  end
end
