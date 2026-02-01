module Api
  module V1
    class NotificationsController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!
      before_action :set_company

      # GET /api/v1/companies/:company_id/notifications
      def index
        notifications = @company.notifications
          .where(user: current_user)
          .order(created_at: :desc)
          .limit(params[:limit] || 30)

        render json: {
          notifications: notifications.map { |n|
            {
              id: n.id,
              type: n.notification_type,
              title: n.title,
              body: n.body,
              read: n.read,
              data: n.data,
              created_at: n.created_at
            }
          },
          unread_count: @company.notifications.where(user: current_user).unread.count
        }
      end

      # PATCH /api/v1/companies/:company_id/notifications/:id/read
      def mark_read
        notification = @company.notifications.where(user: current_user).find(params[:id])
        notification.mark_read!
        render json: { success: true }
      end

      # POST /api/v1/companies/:company_id/notifications/read_all
      def read_all
        @company.notifications.where(user: current_user).unread.update_all(read: true)
        render json: { success: true }
      end

      private

      def set_company
        @company = current_user.accessible_companies.find(params[:company_id])
      end
    end
  end
end
