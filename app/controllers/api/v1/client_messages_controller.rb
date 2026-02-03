module Api
  module V1
    class ClientMessagesController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!
      before_action :set_company

      # GET /api/v1/companies/:company_id/messages
      def index
        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 50).to_i

        messages = @company.client_messages
          .includes(:user)
          .chronological

        total = messages.count
        messages = messages.offset((page - 1) * per_page).limit(per_page)

        render json: {
          messages: messages.map { |m| serialize_message(m) },
          pagination: {
            page: page,
            per_page: per_page,
            total: total,
            total_pages: (total.to_f / per_page).ceil
          }
        }
      end

      # POST /api/v1/companies/:company_id/messages
      def create
        message = @company.client_messages.build(
          user: current_user,
          body: params[:body]
        )

        if message.save
          render json: { message: serialize_message(message.reload) }, status: :created
        else
          render json: { errors: message.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/companies/:company_id/messages/:id
      def destroy
        message = @company.client_messages.find(params[:id])

        unless message.user_id == current_user.id || current_user.global_access?
          return render json: { error: 'Not authorized' }, status: :forbidden
        end

        message.destroy
        render json: { success: true }
      end

      # GET /api/v1/companies/:company_id/messages/participants
      # Returns all users who can participate in this company's message thread
      def participants
        # All company members + global users (executive/manager)
        company_user_ids = @company.company_users.pluck(:user_id)
        global_users = User.where(role: %w[executive manager]).where.not(id: company_user_ids)

        company_members = @company.users.select(:id, :first_name, :last_name, :email, :role)
        globals = global_users.select(:id, :first_name, :last_name, :email, :role)

        all_users = (company_members + globals).uniq(&:id)

        render json: {
          users: all_users.map { |u|
            {
              id: u.id,
              first_name: u.first_name,
              last_name: u.last_name,
              name: "#{u.first_name} #{u.last_name}".strip,
              email: u.email,
              role: u.role
            }
          }
        }
      end

      private

      def set_company
        @company = current_user.accessible_companies.find(params[:company_id])
      end

      def serialize_message(message)
        {
          id: message.id,
          body: message.body,
          user: {
            id: message.user.id,
            first_name: message.user.first_name,
            last_name: message.user.last_name,
            name: "#{message.user.first_name} #{message.user.last_name}".strip,
            email: message.user.email,
            role: message.user.role
          },
          mentioned_user_ids: message.mentioned_user_ids || [],
          created_at: message.created_at,
          is_author: message.user_id == current_user.id
        }
      end
    end
  end
end
