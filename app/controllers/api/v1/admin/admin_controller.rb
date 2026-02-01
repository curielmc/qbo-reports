module Api
  module V1
    module Admin
      class AdminController < ApplicationController
        skip_before_action :verify_authenticity_token
        before_action :authenticate_user!
        before_action :authorize_admin!

        private

        def authorize_admin!
          unless current_user.executive? || current_user.manager?
            render json: { error: 'Unauthorized' }, status: :forbidden
          end
        end
      end
    end
  end
end
