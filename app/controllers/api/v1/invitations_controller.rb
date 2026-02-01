module Api
  module V1
    class InvitationsController < ApplicationController
      skip_before_action :verify_authenticity_token

      # GET /api/v1/invitations/:token
      # Public - returns invitation details for the setup form
      def show
        invitation = Invitation.find_by!(token: params[:token])

        if invitation.accepted?
          render json: { error: 'This invitation has already been used', status: 'accepted' }, status: :gone
        elsif invitation.expired?
          render json: { error: 'This invitation has expired', status: 'expired' }, status: :gone
        else
          render json: {
            email: invitation.email,
            first_name: invitation.first_name,
            last_name: invitation.last_name,
            role: invitation.role,
            household_name: invitation.household&.name,
            personal_message: invitation.personal_message,
            status: 'pending'
          }
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Invalid invitation link' }, status: :not_found
      end

      # POST /api/v1/invitations/:token/accept
      # Public - creates user account from invitation
      def accept
        invitation = Invitation.find_by!(token: params[:token])

        if invitation.accepted?
          render json: { error: 'This invitation has already been used' }, status: :gone
          return
        end

        if invitation.expired?
          render json: { error: 'This invitation has expired' }, status: :gone
          return
        end

        user = User.new(
          email: invitation.email,
          first_name: params[:first_name] || invitation.first_name,
          last_name: params[:last_name] || invitation.last_name,
          password: params[:password],
          password_confirmation: params[:password_confirmation],
          role: invitation.role
        )

        if user.save
          invitation.accept!(user)

          # Auto-login: generate JWT token
          token = JWT.encode(
            { user_id: user.id, email: user.email, role: user.role, exp: 24.hours.from_now.to_i },
            Rails.application.credentials.secret_key_base
          )

          render json: {
            message: 'Account created successfully',
            token: token,
            user: {
              id: user.id,
              email: user.email,
              first_name: user.first_name,
              last_name: user.last_name,
              role: user.role
            }
          }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Invalid invitation link' }, status: :not_found
      end
    end
  end
end
