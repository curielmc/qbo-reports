module Api
  module V1
    class StatementsController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!
      before_action :set_company

      # POST /api/v1/companies/:company_id/statements/upload
      # Upload and parse a bank statement
      def upload
        file = params[:file]
        return render json: { error: 'No file uploaded' }, status: :unprocessable_entity unless file

        upload = @company.statement_uploads.create!(
          user: current_user,
          filename: file.original_filename,
          file_type: File.extname(file.original_filename).delete('.').downcase,
          status: 'parsing'
        )

        begin
          parser = StatementParser.new(@company)
          result = parser.parse(file.read, file.original_filename)

          if result[:success]
            upload.update!(
              status: 'parsed',
              transactions_found: result[:count],
              raw_data: { transactions: result[:transactions], account_name: result[:account_name], account_type: result[:account_type] },
              parse_notes: result[:notes]
            )

            render json: {
              upload_id: upload.id,
              status: 'parsed',
              transactions_found: result[:count],
              account_name: result[:account_name],
              account_type: result[:account_type],
              notes: result[:notes],
              preview: result[:transactions].first(10).map { |t|
                { date: t['date'], description: t['description'], amount: t['amount'], suggested_category: t['suggested_category'] }
              },
              message: "Found #{result[:count]} transactions. Review the preview and confirm to import."
            }
          else
            upload.update!(status: 'failed', error_message: result[:error])
            render json: { error: result[:error] }, status: :unprocessable_entity
          end
        rescue => e
          upload.update!(status: 'failed', error_message: e.message)
          render json: { error: "Parse failed: #{e.message}" }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/companies/:company_id/statements/:id/import
      # Import parsed transactions into an account
      def import
        upload = @company.statement_uploads.find(params[:id])

        # Find or create the account
        account = if params[:account_id].present?
          @company.accounts.find(params[:account_id])
        elsif params[:account_name].present?
          @company.accounts.find_or_create_by!(name: params[:account_name]) do |a|
            a.account_type = upload.raw_data.dig('account_type') || 'checking'
            a.current_balance = 0
          end
        else
          return render json: { error: 'Specify account_id or account_name' }, status: :unprocessable_entity
        end

        parser = StatementParser.new(@company)
        result = parser.import(upload, account)

        render json: {
          message: "Imported #{result[:imported]} transactions, #{result[:categorized]} auto-categorized, #{result[:skipped_duplicates]} duplicates skipped.",
          imported: result[:imported],
          categorized: result[:categorized],
          skipped_duplicates: result[:skipped_duplicates]
        }
      end

      # GET /api/v1/companies/:company_id/statements
      # List recent uploads
      def index
        uploads = @company.statement_uploads.recent.limit(20)
        render json: uploads.map { |u|
          {
            id: u.id,
            filename: u.filename,
            file_type: u.file_type,
            status: u.status,
            transactions_found: u.transactions_found,
            transactions_imported: u.transactions_imported,
            transactions_categorized: u.transactions_categorized,
            parse_notes: u.parse_notes,
            error_message: u.error_message,
            account_name: u.account&.name,
            created_at: u.created_at
          }
        }
      end

      # GET /api/v1/companies/:company_id/statements/:id/preview
      # Preview parsed transactions before import
      def preview
        upload = @company.statement_uploads.find(params[:id])
        render json: {
          upload_id: upload.id,
          filename: upload.filename,
          status: upload.status,
          transactions: upload.parsed_transactions.map { |t|
            { date: t['date'], description: t['description'], amount: t['amount'], merchant: t['merchant'], suggested_category: t['suggested_category'] }
          }
        }
      end

      private

      def set_company
        @company = current_user.accessible_companies.find(params[:company_id])
      end
    end
  end
end
