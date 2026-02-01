module Api
  module V1
    module Admin
      class UsersController < AdminController
        def index
          users = User.all.order(:last_name, :first_name)
          render json: users.map { |u|
            {
              id: u.id,
              first_name: u.first_name,
              last_name: u.last_name,
              email: u.email,
              role: u.role,
              companies_count: u.companies.count,
              last_sign_in_at: u.last_sign_in_at,
              created_at: u.created_at
            }
          }
        end

        def create
          user = User.new(user_params)
          if user.save
            render json: { id: user.id, message: 'User created' }, status: :created
          else
            render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def update
          user = User.find(params[:id])
          update_params = user_params.reject { |_, v| v.blank? }
          if user.update(update_params)
            render json: { message: 'User updated' }
          else
            render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def destroy
          user = User.find(params[:id])
          if user == current_user
            render json: { error: "Can't delete yourself" }, status: :unprocessable_entity
          else
            user.destroy
            render json: { message: 'User deleted' }
          end
        end

        private

        def user_params
          params.require(:user).permit(:first_name, :last_name, :email, :password, :role)
        end
      end
    end
  end
end
