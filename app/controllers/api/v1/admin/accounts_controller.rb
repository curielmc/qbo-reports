module Api
  module V1
    module Admin
      class AccountsController < AdminController
        # GET /api/v1/admin/accounts
        def index
          accounts = Account.includes(:household).order(:name)
          render json: accounts.map { |a|
            {
              id: a.id,
              name: a.name,
              institution: a.institution,
              account_type: a.account_type,
              mask: a.mask,
              active: a.active,
              household_id: a.household_id,
              household_name: a.household&.name,
              created_at: a.created_at
            }
          }
        end

        # POST /api/v1/admin/accounts
        def create
          account = Account.new(account_params)
          if account.save
            render json: account, status: :created
          else
            render json: { errors: account.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # PUT /api/v1/admin/accounts/:id
        def update
          account = Account.find(params[:id])
          if account.update(account_params)
            render json: account
          else
            render json: { errors: account.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/admin/accounts/:id
        def destroy
          account = Account.find(params[:id])
          account.destroy
          render json: { message: 'Account deleted' }
        end

        private

        def account_params
          params.require(:account).permit(:name, :institution, :account_type, :mask, :household_id, :active, :plaid_account_id)
        end
      end
    end
  end
end
