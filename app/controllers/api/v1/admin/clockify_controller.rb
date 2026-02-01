module Api
  module V1
    module Admin
      class ClockifyController < AdminController
        # GET /api/v1/admin/clockify/projects
        def projects
          clockify = ClockifyService.new
          projects = clockify.list_projects || []
          render json: projects.map { |p|
            {
              id: p['id'],
              name: p['name'],
              client_name: p.dig('client', 'name'),
              archived: p['archived']
            }
          }
        end

        # GET /api/v1/admin/clockify/clients
        def clients
          clockify = ClockifyService.new
          clients = clockify.list_clients || []
          render json: clients.map { |c|
            { id: c['id'], name: c['name'] }
          }
        end

        # GET /api/v1/admin/clockify/summary
        # Hours summary for current month across all projects
        def summary
          clockify = ClockifyService.new
          start_date = params[:start_date] ? Date.parse(params[:start_date]) : Date.current.beginning_of_month
          end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.current

          summary = clockify.summary(start_date: start_date, end_date: end_date)
          render json: summary
        end

        # POST /api/v1/admin/clockify/setup/:company_id
        # Auto-create Clockify client + project for a company
        def setup
          company = Company.find(params[:company_id])
          clockify = ClockifyService.new

          # Find or create Clockify client
          client = clockify.find_client(company.name) || clockify.create_client(company.name)
          return render json: { error: 'Failed to create Clockify client' }, status: :unprocessable_entity unless client

          # Find or create project
          project = clockify.find_project(company.name) || clockify.create_project(
            "#{company.name} - Bookkeeping",
            client_id: client['id']
          )
          return render json: { error: 'Failed to create Clockify project' }, status: :unprocessable_entity unless project

          # Link to company
          company.update!(
            clockify_client_id: client['id'],
            clockify_project_id: project['id']
          )

          render json: {
            message: "Linked #{company.name} to Clockify",
            clockify_client: client['name'],
            clockify_project: project['name'],
            project_id: project['id']
          }
        end
      end
    end
  end
end
