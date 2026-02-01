module Api
  module V1
    class ImportsController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!
      before_action :set_company

      # POST /api/v1/companies/:company_id/imports/upload
      # Upload and preview — doesn't commit yet
      def upload
        file = params[:file]
        return render json: { error: 'File required' }, status: :unprocessable_entity unless file

        content = file.read
        filename = file.original_filename

        importer = DataImporter.new(@company, current_user)
        preview = importer.import(content, filename)

        # Store parsed data in cache for commit step
        cache_key = "import_#{@company.id}_#{SecureRandom.hex(8)}"
        Rails.cache.write(cache_key, { data: preview[:data], filename: filename }, expires_in: 1.hour)

        # Track usage
        UsageMeter.new(@company, current_user).track('data_import', summary: "Import: #{filename}")

        render json: {
          import_key: cache_key,
          source: preview[:source],
          summary: preview[:summary],
          warnings: preview[:warnings],
          category_mapping: preview[:data][:category_mapping],
          suggested_new_categories: preview[:data][:suggested_new_categories],
          sample_transactions: (preview[:data][:transactions] || []).first(20).map { |t|
            {
              date: t[:date],
              description: t[:description],
              amount: t[:amount],
              category: t[:mapped_category] || t[:category],
              merchant: t[:merchant],
              account: t[:account_name]
            }
          }
        }
      end

      # POST /api/v1/companies/:company_id/imports/commit
      # Commit a previewed import
      def commit
        cache_key = params[:import_key]
        cached = Rails.cache.read(cache_key)
        return render json: { error: 'Import expired or not found. Please upload again.' }, status: :not_found unless cached

        importer = DataImporter.new(@company, current_user)

        # Apply any user overrides
        if params[:create_new_categories]
          (cached[:data][:suggested_new_categories] || []).each do |cat|
            code = ChartOfAccountTemplates.next_code(@company, cat['account_type'] || 'expense')
            @company.chart_of_accounts.find_or_create_by!(name: cat['name']) do |coa|
              coa.account_type = cat['account_type'] || 'expense'
              coa.code = code
              coa.active = true
            end
          end
        end

        results = importer.commit(cached[:data])

        # Clean up cache
        Rails.cache.delete(cache_key)

        render json: {
          success: true,
          results: results,
          message: "Imported #{results[:created][:transactions] || 0} transactions, " \
                   "#{results[:skipped][:duplicates] || 0} duplicates skipped, " \
                   "#{results[:auto_categorized] || 0} auto-categorized."
        }
      end

      # GET /api/v1/companies/:company_id/imports/supported
      def supported
        render json: {
          formats: [
            { id: 'quickbooks_online', name: 'QuickBooks Online', extensions: ['.csv', '.qbo', '.json'], icon: '📗' },
            { id: 'quickbooks_desktop', name: 'QuickBooks Desktop', extensions: ['.iif', '.csv'], icon: '📘' },
            { id: 'xero', name: 'Xero', extensions: ['.csv'], icon: '📋' },
            { id: 'freshbooks', name: 'FreshBooks', extensions: ['.csv'], icon: '📒' },
            { id: 'wave', name: 'Wave', extensions: ['.csv'], icon: '🌊' },
            { id: 'ofx_qfx', name: 'Bank Export (OFX/QFX)', extensions: ['.ofx', '.qfx'], icon: '🏦' },
            { id: 'generic_csv', name: 'Generic CSV / Excel', extensions: ['.csv', '.xls', '.xlsx'], icon: '📄' }
          ],
          notes: [
            'AI auto-detects the format — just upload and we figure it out.',
            'Categories from your old system are mapped to ecfoBooks automatically.',
            'Duplicates are detected and skipped.',
            'You get a preview before anything is committed.'
          ]
        }
      end

      private

      def set_company
        @company = current_user.accessible_companies.find(params[:company_id])
      end
    end
  end
end
