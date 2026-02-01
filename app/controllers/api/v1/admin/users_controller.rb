module Api
  module V1
    module Admin
      class UsersController < AdminController
        before_action :require_executive!, only: [:create, :update, :destroy]

        # GET /api/v1/admin/users
        # Both executives and managers can see all users
        def index
          users = User.all.order(:last_name, :first_name)
          render json: users.map { |u|
            {
              id: u.id,
              email: u.email,
              first_name: u.first_name,
              last_name: u.last_name,
              role: u.role,
              company_count: u.companies.count,
              created_at: u.created_at,
              # Managers can see but not the edit controls
              editable: current_user.admin_access?
            }
          }
        end

        # POST /api/v1/admin/users (executive only)
        def create
          user = User.new(user_params)
          if user.save
            render json: serialize_user(user), status: :created
          else
            render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # PUT /api/v1/admin/users/:id (executive only)
        def update
          user = User.find(params[:id])
          update_params = user_params.reject { |_, v| v.blank? }
          if user.update(update_params)
            render json: serialize_user(user)
          else
            render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/admin/users/:id (executive only)
        def destroy
          user = User.find(params[:id])
          user.destroy
          render json: { message: 'User deleted' }
        end

        private

        def user_params
          params.require(:user).permit(:email, :first_name, :last_name, :role, :password, :password_confirmation)
        end

        def serialize_user(user)
          {
            id: user.id,
            email: user.email,
            first_name: user.first_name,
            last_name: user.last_name,
            role: user.role,
            company_count: user.companies.count,
            created_at: user.created_at,
            editable: current_user.admin_access?
          }
        end
      end
    end
  end
end
