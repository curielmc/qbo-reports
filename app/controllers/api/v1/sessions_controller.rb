module Api
  module V1
    class SessionsController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!, only: [:show, :destroy]

      # POST /api/v1/auth/login
      def create
        user = User.find_by(email: params[:email]&.downcase)
        
        if user&.valid_password?(params[:password])
          token = generate_jwt(user)
          render json: {
            token: token,
            user: {
              id: user.id,
              email: user.email,
              first_name: user.first_name,
              last_name: user.last_name,
              role: user.role
            }
          }
        else
          render json: { error: 'Invalid email or password' }, status: :unauthorized
        end
      end

      # GET /api/v1/auth/me
      def show
        render json: {
          user: {
            id: current_user.id,
            email: current_user.email,
            first_name: current_user.first_name,
            last_name: current_user.last_name,
            role: current_user.role
          }
        }
      end

      # DELETE /api/v1/auth/logout
      def destroy
        # JWT is stateless — client just discards the token
        render json: { message: 'Logged out successfully' }
      end

      private

      def generate_jwt(user)
        payload = {
          user_id: user.id,
          email: user.email,
          role: user.role,
          exp: 24.hours.from_now.to_i
        }
        JWT.encode(payload, Rails.application.credentials.secret_key_base)
      end
    end
  end
end
