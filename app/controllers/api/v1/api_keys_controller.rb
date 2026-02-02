class Api::V1::ApiKeysController < ApplicationController
  before_action :authenticate_user!

  # POST /api/v1/api_keys
  def create
    company = current_user.accessible_companies.find_by(id: params[:company_id])
    unless company
      return render json: { error: 'Company not found or not accessible' }, status: :not_found
    end

    api_key, raw_token = ApiKey.generate!(
      user: current_user,
      company: company,
      name: params[:name] || 'API Key',
      permissions: params[:permissions] || [],
      expires_at: params[:expires_at]
    )

    render json: {
      token: raw_token,
      warning: 'Save this token now. It will not be shown again.',
      api_key: {
        id: api_key.id,
        prefix: api_key.prefix,
        name: api_key.name,
        company_id: api_key.company_id,
        permissions: api_key.permissions,
        expires_at: api_key.expires_at,
        created_at: api_key.created_at
      }
    }, status: :created
  end

  # GET /api/v1/api_keys
  def index
    keys = current_user.api_keys.order(created_at: :desc).map do |key|
      {
        id: key.id,
        prefix: key.prefix,
        name: key.name,
        company_id: key.company_id,
        company_name: key.company.name,
        permissions: key.permissions,
        active: key.active,
        expires_at: key.expires_at,
        last_used_at: key.last_used_at,
        created_at: key.created_at
      }
    end

    render json: { api_keys: keys }
  end

  # DELETE /api/v1/api_keys/:id
  def destroy
    api_key = current_user.api_keys.find_by(id: params[:id])
    unless api_key
      return render json: { error: 'API key not found' }, status: :not_found
    end

    api_key.revoke!
    render json: { message: 'API key revoked', id: api_key.id }
  end
end
