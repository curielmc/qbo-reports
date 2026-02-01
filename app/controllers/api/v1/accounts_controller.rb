module Api
  module V1
    class AccountsController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!
      before_action :set_household

      # GET /api/v1/households/:household_id/accounts
      def index
        accounts = @household.accounts.order(:name)
        render json: accounts.map { |a| serialize(a) }
      end

      # POST /api/v1/households/:household_id/accounts
      def create
        account = @household.accounts.build(account_params)
        if account.save
          render json: serialize(account), status: :created
        else
          render json: { errors: account.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/households/:household_id/accounts/:id
      def update
        account = @household.accounts.find(params[:id])
        if account.update(account_params)
          render json: serialize(account)
        else
          render json: { errors: account.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/households/:household_id/accounts/:id
      def destroy
        account = @household.accounts.find(params[:id])
        account.destroy
        render json: { message: 'Account deleted' }
      end

      private

      def set_household
        @household = current_user.accessible_households.find(params[:household_id])
      end

      def account_params
        params.require(:account).permit(:name, :institution, :account_type, :mask, :active)
      end

      def serialize(a)
        {
          id: a.id,
          name: a.name,
          institution: a.institution,
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
