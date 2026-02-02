class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception, unless: -> { request.format.json? }

  private

  def authenticate_user!
    token = request.headers['Authorization']&.split(' ')&.last
    if token
      if token.start_with?('sk-')
        authenticate_with_api_key!(token)
      else
        authenticate_with_jwt!(token)
      end
    else
      # Fall back to Devise session auth
      unless current_user
        render json: { error: 'Authentication required' }, status: :unauthorized
      end
    end
  end

  def authenticate_with_jwt!(token)
    @jwt_payload = JWT.decode(token, Rails.application.secret_key_base)[0]
    @current_user = User.find(@jwt_payload['user_id'])
  rescue JWT::DecodeError, ActiveRecord::RecordNotFound
    render json: { error: 'Invalid or expired token' }, status: :unauthorized
  end

  def authenticate_with_api_key!(token)
    api_key = ApiKey.find_by_token(token)
    if api_key
      @current_api_key = api_key
      @current_user = api_key.user
      @api_key_company = api_key.company
      api_key.touch_last_used!
    else
      render json: { error: 'Invalid or expired API key' }, status: :unauthorized
    end
  end

  def jwt_payload
    @jwt_payload || {}
  end

  def real_user
    real_id = jwt_payload['real_user_id']
    real_id ? User.find(real_id) : current_user
  end

  def current_user
    @current_user || super
  rescue
    nil
  end

  def current_api_key
    @current_api_key
  end

  # Resolve company from params, respecting API key scoping
  def resolve_company
    if @api_key_company
      # API key is scoped to a single company
      company_id = params[:company_id] || @api_key_company.id
      if company_id.to_i == @api_key_company.id
        @api_key_company
      else
        render json: { error: 'API key not authorized for this company' }, status: :forbidden
        nil
      end
    else
      current_user&.accessible_companies&.find_by(id: params[:company_id])
    end
  end

  def require_permission!(permission)
    return unless current_api_key
    unless current_api_key.can?(permission)
      render json: { error: "API key lacks '#{permission}' permission" }, status: :forbidden
    end
  end
end
