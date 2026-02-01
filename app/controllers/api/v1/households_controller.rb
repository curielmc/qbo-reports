module Api
  module V1
    class HouseholdsController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!

      # GET /api/v1/households
      def index
        households = current_user.accessible_households.order(:name)
        render json: households.map { |h|
          {
            id: h.id,
            name: h.name,
            accounts_count: h.accounts.count,
            transactions_count: h.transactions.count,
            created_at: h.created_at
          }
        }
      end

      # GET /api/v1/households/:id
      def show
        household = current_user.accessible_households.find(params[:id])
        accounts_with_balances = household.accounts.active.map do |a|
          {
            id: a.id,
            name: a.name,
            institution: a.institution,
            account_type: a.account_type,
            mask: a.mask,
            current_balance: a.current_balance,
            available_balance: a.available_balance,
            active: a.active
          }
        end

        render json: {
          id: household.id,
          name: household.name,
          accounts: accounts_with_balances,
          total_assets: accounts_with_balances.select { |a| %w[checking savings depository investment brokerage].include?(a[:account_type]) }
                          .sum { |a| a[:current_balance].to_f },
          total_liabilities: accounts_with_balances.select { |a| %w[credit credit_card loan mortgage].include?(a[:account_type]) }
                               .sum { |a| a[:current_balance].to_f.abs },
          created_at: household.created_at
        }
      end
    end
  end
end
