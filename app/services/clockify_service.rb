require 'net/http'
require 'json'

class ClockifyService
  BASE_URL = 'https://api.clockify.me/api/v1'

  def initialize(api_key: nil, workspace_id: nil)
    @api_key = api_key || Rails.application.credentials.dig(:clockify, :api_key) || ENV['CLOCKIFY_API_KEY']
    @workspace_id = workspace_id || Rails.application.credentials.dig(:clockify, :workspace_id) || ENV['CLOCKIFY_WORKSPACE_ID']
  end

  # ============================================
  # PROJECTS (one per client engagement)
  # ============================================

  def list_projects
    get("/workspaces/#{@workspace_id}/projects?page-size=200")
  end

  def find_project(name)
    projects = list_projects
    projects&.find { |p| p['name'].downcase.include?(name.downcase) }
  end

  def create_project(name, client_id: nil)
    body = { name: name, isPublic: false }
    body[:clientId] = client_id if client_id
    post("/workspaces/#{@workspace_id}/projects", body)
  end

  # ============================================
  # CLIENTS
  # ============================================

  def list_clients
    get("/workspaces/#{@workspace_id}/clients?page-size=200")
  end

  def find_client(name)
    clients = list_clients
    clients&.find { |c| c['name'].downcase.include?(name.downcase) }
  end

  def create_client(name)
    post("/workspaces/#{@workspace_id}/clients", { name: name })
  end

  # ============================================
  # TIME ENTRIES
  # ============================================

  # Get time entries for a project in a date range
  def time_entries(project_id: nil, user_id: nil, start_date: nil, end_date: nil)
    params = { 'page-size' => 200 }
    params['project'] = project_id if project_id
    params['start'] = start_date.to_time.utc.iso8601 if start_date
    params['end'] = end_date.to_time.utc.iso8601 if end_date

    if user_id
      query = params.map { |k, v| "#{k}=#{v}" }.join('&')
      get("/workspaces/#{@workspace_id}/user/#{user_id}/time-entries?#{query}")
    else
      # Get all users' entries via reports
      report_entries(project_id: project_id, start_date: start_date, end_date: end_date)
    end
  end

  # Detailed report (all users, filterable)
  def report_entries(project_id: nil, start_date: nil, end_date: nil)
    start_date ||= Date.current.beginning_of_month
    end_date ||= Date.current

    body = {
      dateRangeStart: start_date.to_time.utc.iso8601,
      dateRangeEnd: end_date.to_time.utc.iso8601,
      detailedFilter: { page: 1, pageSize: 200 }
    }
    body[:projects] = { ids: [project_id], contains: 'CONTAINS', status: 'ALL' } if project_id

    result = post_reports("/workspaces/#{@workspace_id}/reports/detailed", body)
    result&.dig('timeentries') || []
  end

  # Summary: total hours per project for a period
  def summary(start_date: nil, end_date: nil)
    start_date ||= Date.current.beginning_of_month
    end_date ||= Date.current

    body = {
      dateRangeStart: start_date.to_time.utc.iso8601,
      dateRangeEnd: end_date.to_time.utc.iso8601,
      summaryFilter: { groups: ['PROJECT'] }
    }

    result = post_reports("/workspaces/#{@workspace_id}/reports/summary", body)
    (result&.dig('groupOne') || []).map do |group|
      {
        project_id: group['_id'],
        project_name: group['name'],
        total_seconds: group['duration'],
        total_hours: (group['duration'] / 3600.0).round(2),
        total_amount: group['amount']&.[]('value')
      }
    end
  end

  # ============================================
  # USERS / TEAM
  # ============================================

  def list_users
    get("/workspaces/#{@workspace_id}/users")
  end

  def current_user
    get('/user')
  end

  private

  def get(path)
    uri = URI("#{BASE_URL}#{path}")
    request = Net::HTTP::Get.new(uri)
    request['X-Api-Key'] = @api_key
    request['Content-Type'] = 'application/json'

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 15) do |http|
      http.request(request)
    end

    return nil unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)
  rescue => e
    Rails.logger.error "Clockify GET error: #{e.message}"
    nil
  end

  def post(path, body)
    uri = URI("#{BASE_URL}#{path}")
    request = Net::HTTP::Post.new(uri)
    request['X-Api-Key'] = @api_key
    request['Content-Type'] = 'application/json'
    request.body = body.to_json

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 15) do |http|
      http.request(request)
    end

    return nil unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)
  rescue => e
    Rails.logger.error "Clockify POST error: #{e.message}"
    nil
  end

  def post_reports(path, body)
    uri = URI("https://reports.api.clockify.me/v1#{path}")
    request = Net::HTTP::Post.new(uri)
    request['X-Api-Key'] = @api_key
    request['Content-Type'] = 'application/json'
    request.body = body.to_json

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 15) do |http|
      http.request(request)
    end

    return nil unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)
  rescue => e
    Rails.logger.error "Clockify Reports error: #{e.message}"
    nil
  end
end
