class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception, unless: -> { request.format.json? }

  private

  def authenticate_user!
    token = request.headers['Authorization']&.split(' ')&.last
    if token
      begin
        payload = JWT.decode(token, Rails.application.credentials.secret_key_base)[0]
        @current_user = User.find(payload['user_id'])
      rescue JWT::DecodeError, ActiveRecord::RecordNotFound
        render json: { error: 'Invalid or expired token' }, status: :unauthorized
      end
    else
      # Fall back to Devise session auth
      unless current_user
        render json: { error: 'Authentication required' }, status: :unauthorized
      end
    end
  end

  def current_user
    @current_user || super
  rescue
    nil
  end
end
