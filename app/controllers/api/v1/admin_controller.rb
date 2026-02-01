module Api
  module V1
    class AdminController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!
      before_action :require_admin!

      private

      def require_admin!
        unless current_user&.admin? || current_user&.executive?
          render json: { error: 'Admin access required' }, status: :forbidden
        end
      end
    end
  end
end
