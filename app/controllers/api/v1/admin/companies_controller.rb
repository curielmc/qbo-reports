module Api
  module V1
    module Admin
      class CompaniesController < AdminController
        # GET /api/v1/admin/companies
        def index
          companies = Company.all.order(:name)
          render json: companies.map { |h|
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

        # POST /api/v1/admin/companies
        def create
          company = Company.new(company_params)
          if company.save
            render json: company, status: :created
          else
            render json: { errors: company.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # PUT /api/v1/admin/companies/:id
        def update
          company = Company.find(params[:id])
          if company.update(company_params)
            render json: company
          else
            render json: { errors: company.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/admin/companies/:id
        def destroy
          company = Company.find(params[:id])
          company.destroy
          render json: { message: 'Company deleted' }
        end

        # GET /api/v1/admin/companies/:id/members
        def members
          company = Company.find(params[:id])
          members = company.company_users.includes(:user).map do |hu|
            user = hu.user
            {
              id: user.id,
              first_name: user.first_name,
              last_name: user.last_name,
              email: user.email,
              company_role: hu.role
            }
          end
          render json: members
        end

        # POST /api/v1/admin/companies/:id/members
        def add_member
          company = Company.find(params[:id])
          hu = company.company_users.build(user_id: params[:user_id], role: params[:role] || 'client')
          if hu.save
            render json: { message: 'Member added' }, status: :created
          else
            render json: { errors: hu.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # PUT /api/v1/admin/companies/:id/members/:user_id
        def update_member
          hu = CompanyUser.find_by!(company_id: params[:id], user_id: params[:user_id])
          hu.update!(role: params[:role])
          render json: { message: 'Member updated' }
        end

        # DELETE /api/v1/admin/companies/:id/members/:user_id
        def remove_member
          hu = CompanyUser.find_by!(company_id: params[:id], user_id: params[:user_id])
          hu.destroy
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
