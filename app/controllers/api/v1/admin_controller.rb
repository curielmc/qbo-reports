module Api
  module V1
    class AdminController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!
      before_action :require_elevated_access!

      private

      # Executive + Manager can access admin views
      def require_elevated_access!
        unless current_user&.global_access?
          render json: { error: 'Access denied' }, status: :forbidden
        end
      end

      # Only executives can modify users and system settings
      def require_executive!
        unless current_user&.admin_access?
          render json: { error: 'Executive access required' }, status: :forbidden
        end
      end
    end
  end
end
