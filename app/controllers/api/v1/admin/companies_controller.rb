module Api
  module V1
    module Admin
      class CompaniesController < AdminController
        def index
          companies = Company.all.order(:name)
          render json: companies.map { |c|
            {
              id: c.id,
              name: c.name,
              members_count: c.users.count,
              accounts_count: c.accounts.count,
              transactions_count: c.account_transactions.count,
              created_at: c.created_at
            }
          }
        end

        def create
          company = Company.new(company_params)
          if company.save
            # Add creator as member
            company.company_users.create!(user: current_user, role: 'owner')
            render json: { id: company.id, message: 'Company created' }, status: :created
          else
            render json: { errors: company.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def update
          company = Company.find(params[:id])
          if company.update(company_params)
            render json: { message: 'Company updated' }
          else
            render json: { errors: company.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def destroy
          company = Company.find(params[:id])
          company.destroy
          render json: { message: 'Company deleted' }
        end

        # GET /api/v1/admin/companies/:id/members
        def members
          company = Company.find(params[:id])
          render json: company.company_users.includes(:user).map { |cu|
            {
              user_id: cu.user_id,
              first_name: cu.user.first_name,
              last_name: cu.user.last_name,
              email: cu.user.email,
              role: cu.role
            }
          }
        end

        # POST /api/v1/admin/companies/:id/members
        def add_member
          company = Company.find(params[:id])
          cu = company.company_users.build(user_id: params[:user_id], role: params[:role] || 'viewer')
          if cu.save
            render json: { message: 'Member added' }, status: :created
          else
            render json: { errors: cu.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # PUT /api/v1/admin/companies/:id/members/:user_id
        def update_member
          company = Company.find(params[:id])
          cu = company.company_users.find_by!(user_id: params[:user_id])
          cu.update!(role: params[:role])
          render json: { message: 'Member updated' }
        end

        # DELETE /api/v1/admin/companies/:id/members/:user_id
        def remove_member
          company = Company.find(params[:id])
          company.company_users.find_by!(user_id: params[:user_id]).destroy
          render json: { message: 'Member removed' }
        end

        private

        def company_params
          params.require(:company).permit(:name)
        end
      end
    end
  end
end
