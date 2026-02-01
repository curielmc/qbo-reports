module Api
  module V1
    class AuditLogsController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!
      before_action :set_company

      # GET /api/v1/companies/:company_id/audit_logs
      def index
        logs = @company.audit_logs.order(created_at: :desc).limit(params[:limit] || 50)
        logs = logs.where(action: params[:action]) if params[:action]
        logs = logs.where(user_id: params[:user_id]) if params[:user_id]

        render json: logs.map { |l|
          {
            id: l.id,
            action: l.action,
            resource_type: l.resource_type,
            resource_id: l.resource_id,
            changes: l.changes_made,
            user: l.user.name,
            created_at: l.created_at
          }
        }
      end

      private

      def set_company
        @company = current_user.accessible_companies.find(params[:company_id])
      end
    end
  end
end
