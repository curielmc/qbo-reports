module Api
  module V1
    class ChatController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!
      before_action :set_company

      # POST /api/v1/companies/:company_id/chat
      def create
        message = params[:message]&.strip
        return render json: { error: 'Message required' }, status: :unprocessable_entity if message.blank?

        # Save user message
        user_msg = @company.chat_messages.create!(
          user: current_user,
          role: 'user',
          content: message
        )

        # Get conversation history
        history = @company.chat_messages
          .where(user: current_user)
          .order(created_at: :desc)
          .limit(20)
          .reverse
          .map { |m| { role: m.role, content: m.content } }

        # Run AI
        ai = BookkeeperAi.new(@company, current_user)
        result = ai.chat(message, history[0..-2]) # exclude current message (already sent)

        # Save assistant response
        assistant_msg = @company.chat_messages.create!(
          user: current_user,
          role: 'assistant',
          content: result[:text],
          metadata: { data: result[:data] }
        )

        render json: {
          message: {
            id: assistant_msg.id,
            role: 'assistant',
            content: result[:text],
            data: result[:data],
            created_at: assistant_msg.created_at
          }
        }
      end

      # GET /api/v1/companies/:company_id/chat
      def index
        messages = @company.chat_messages
          .where(user: current_user)
          .order(created_at: :desc)
          .limit(params[:limit] || 50)
          .reverse

        render json: messages.map { |m|
          {
            id: m.id,
            role: m.role,
            content: m.content,
            data: m.metadata&.dig('data'),
            created_at: m.created_at
          }
        }
      end

      # DELETE /api/v1/companies/:company_id/chat
      def destroy
        @company.chat_messages.where(user: current_user).destroy_all
        render json: { message: 'Chat history cleared' }
      end

      private

      def set_company
        @company = current_user.accessible_companies.find(params[:company_id])
      end
    end
  end
end
