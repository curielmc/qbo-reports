module Api
  module V1
    module Admin
      class UsersController < AdminController
        # GET /api/v1/admin/users
        def index
          users = User.all.order(:last_name, :first_name)
          render json: users.map { |u|
            {
              id: u.id,
              email: u.email,
              first_name: u.first_name,
              last_name: u.last_name,
              role: u.role,
              household_count: u.households.count,
              created_at: u.created_at
            }
          }
        end

        # POST /api/v1/admin/users
        def create
          user = User.new(user_params)
          if user.save
            render json: user, status: :created
          else
            render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # PUT /api/v1/admin/users/:id
        def update
          user = User.find(params[:id])
          update_params = user_params.reject { |_, v| v.blank? }
          if user.update(update_params)
            render json: user
          else
            render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/admin/users/:id
        def destroy
          user = User.find(params[:id])
          user.destroy
          render json: { message: 'User deleted' }
        end

        private

        def user_params
          params.require(:user).permit(:email, :first_name, :last_name, :role, :password, :password_confirmation)
        end
      end
    end
  end
end
