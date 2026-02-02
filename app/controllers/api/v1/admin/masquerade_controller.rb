module Api
  module V1
    module Admin
      class MasqueradeController < AdminController
        # POST /api/v1/admin/masquerade/:user_id
        def create
          require_executive!
          return if performed?

          target_user = User.find(params[:user_id])

          token = generate_jwt(target_user, masquerade: true, real_user_id: current_user.id)
          render json: {
            token: token,
            user: format_user(target_user),
            companies: target_user.accessible_companies.map { |c| format_company(c, target_user) }
          }
        rescue ActiveRecord::RecordNotFound
          render json: { error: 'User not found' }, status: :not_found
        end

        # DELETE /api/v1/admin/masquerade
        def destroy
          real_user_id = jwt_payload['real_user_id']

          unless real_user_id
            render json: { error: 'Not currently masquerading' }, status: :unprocessable_entity
            return
          end

          real = User.find(real_user_id)
          token = generate_jwt(real)
          render json: {
            token: token,
            user: format_user(real),
            companies: real.accessible_companies.map { |c| format_company(c, real) }
          }
        end

        private

        def require_executive!
          unless current_user.executive?
            render json: { error: 'Executive access required' }, status: :forbidden
          end
        end

        def format_user(user)
          {
            id: user.id,
            email: user.email,
            first_name: user.first_name,
            last_name: user.last_name,
            role: user.role,
            is_bookkeeper: user.bookkeeper?,
            is_admin: user.admin_access?
          }
        end

        def format_company(company, user)
          {
            id: company.id,
            name: company.name,
            role: user.role_in(company),
            engagement_type: company.engagement_type,
            business_type: company.try(:business_type)
          }
        end

        def generate_jwt(user, extra_claims = {})
          payload = {
            user_id: user.id,
            email: user.email,
            role: user.role,
            exp: 24.hours.from_now.to_i
          }.merge(extra_claims)
          JWT.encode(payload, Rails.application.secret_key_base)
        end
      end
    end
  end
end
