module Api
  module V1
    class BoxController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!
      before_action :set_company

      # GET /api/v1/companies/:company_id/box/config
      def show_config
        render json: {
          box_folder_url: @company.box_folder_url,
          box_folder_id: @company.box_folder_id,
          has_token: @company.box_developer_token.present?,
          has_jwt: BoxAuth.configured?,
          imported_count: @company.box_imported_files.imported.count
        }
      end

      # PUT /api/v1/companies/:company_id/box/config
      def update_config
        attrs = {}
        attrs[:box_folder_url] = params[:box_folder_url] if params.key?(:box_folder_url)
        attrs[:box_developer_token] = params[:box_developer_token] if params.key?(:box_developer_token)

        # Extract folder ID from URL if provided
        if params[:box_folder_url].present?
          folder_id = extract_folder_id(params[:box_folder_url])
          attrs[:box_folder_id] = folder_id if folder_id
        end

        @company.update!(attrs)
        render json: { success: true, box_folder_id: @company.box_folder_id }
      end

      # POST /api/v1/companies/:company_id/box/sync
      def sync
        unless @company.box_folder_id.present?
          return render json: { error: 'Box folder not configured. Set the folder URL first.' }, status: :unprocessable_entity
        end
        unless @company.box_developer_token.present? || BoxAuth.configured?
          return render json: { error: 'Box not configured. Set a developer token or configure JWT credentials.' }, status: :unprocessable_entity
        end

        # Create sync job record
        sync_job = @company.box_sync_jobs.create!(
          user: current_user,
          status: 'pending'
        )

        # Enqueue the job
        BoxSyncJobRunner.perform_later(@company.id, current_user.id, sync_job.id)

        render json: { sync_job_id: sync_job.id, status: 'pending' }
      end

      # GET /api/v1/companies/:company_id/box/sync_status
      def sync_status
        job = @company.box_sync_jobs.recent.first
        unless job
          return render json: { status: 'none' }
        end

        render json: {
          id: job.id,
          status: job.status,
          total_files: job.total_files,
          processed_files: job.processed_files,
          imported_files: job.imported_files,
          skipped_files: job.skipped_files,
          failed_files: job.failed_files,
          current_file: job.current_file,
          error_message: job.error_message,
          progress_pct: job.progress_pct,
          started_at: job.started_at,
          completed_at: job.completed_at
        }
      end

      # GET /api/v1/companies/:company_id/box/files
      def files
        imported = @company.box_imported_files.recent.limit(50)
        render json: imported.map { |f|
          {
            id: f.id,
            box_file_id: f.box_file_id,
            filename: f.filename,
            folder_path: f.box_folder_path,
            status: f.status,
            error_message: f.error_message,
            imported_at: f.created_at
          }
        }
      end

      # GET /api/v1/companies/:company_id/box/embed_url/:file_id
      def embed_url
        unless @company.box_developer_token.present? || BoxAuth.configured?
          return render json: { error: 'Box not configured' }, status: :unprocessable_entity
        end

        begin
          client = BoxAuth.client_for(@company)
          url = client.embed_url(params[:file_id], show_download: false, show_annotations: false)
          render json: { embed_url: url }
        rescue Boxr::BoxrError => e
          render json: { error: "Box API error: #{e.message}" }, status: :unprocessable_entity
        end
      end

      private

      def set_company
        @company = current_user.accessible_companies.find(params[:company_id])
      end

      def extract_folder_id(url)
        # Box folder URLs look like: https://app.box.com/folder/123456789
        if url =~ /box\.com\/folder\/(\d+)/
          $1
        else
          url.strip
        end
      end
    end
  end
end
