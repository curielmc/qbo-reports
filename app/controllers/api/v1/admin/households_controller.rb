module Api
  module V1
    module Admin
      class HouseholdsController < AdminController
        # GET /api/v1/admin/households
        def index
          households = Household.all.order(:name)
          render json: households.map { |h|
            {
              id: h.id,
              name: h.name,
              users_count: h.users.count,
              accounts_count: h.accounts.count,
              transactions_count: h.respond_to?(:transactions) ? h.transactions.count : 0,
              users: h.users.map { |u| { id: u.id, first_name: u.first_name, last_name: u.last_name, role: u.role } },
              created_at: h.created_at
            }
          }
        end

        # POST /api/v1/admin/households
        def create
          household = Household.new(household_params)
          if household.save
            render json: household, status: :created
          else
            render json: { errors: household.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # PUT /api/v1/admin/households/:id
        def update
          household = Household.find(params[:id])
          if household.update(household_params)
            render json: household
          else
            render json: { errors: household.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/admin/households/:id
        def destroy
          household = Household.find(params[:id])
          household.destroy
          render json: { message: 'Household deleted' }
        end

        # GET /api/v1/admin/households/:id/members
        def members
          household = Household.find(params[:id])
          members = household.household_users.includes(:user).map do |hu|
            user = hu.user
            {
              id: user.id,
              first_name: user.first_name,
              last_name: user.last_name,
              email: user.email,
              household_role: hu.role
            }
          end
          render json: members
        end

        # POST /api/v1/admin/households/:id/members
        def add_member
          household = Household.find(params[:id])
          hu = household.household_users.build(user_id: params[:user_id], role: params[:role] || 'client')
          if hu.save
            render json: { message: 'Member added' }, status: :created
          else
            render json: { errors: hu.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # PUT /api/v1/admin/households/:id/members/:user_id
        def update_member
          hu = HouseholdUser.find_by!(household_id: params[:id], user_id: params[:user_id])
          hu.update!(role: params[:role])
          render json: { message: 'Member updated' }
        end

        # DELETE /api/v1/admin/households/:id/members/:user_id
        def remove_member
          hu = HouseholdUser.find_by!(household_id: params[:id], user_id: params[:user_id])
          hu.destroy
          render json: { message: 'Member removed' }
        end

        private

        def household_params
          params.require(:household).permit(:name)
        end
      end
    end
  end
end
