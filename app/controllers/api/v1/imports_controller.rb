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
        ext = File.extname(filename).downcase

        # PDF/image statements go through the statement parser pipeline
        if ext.in?(%w[.pdf .png .jpg .jpeg])
          return upload_statement(file, content, filename)
        end

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

        # Apply user edits from the editable preview
        if params[:modified_transactions].present?
          params[:modified_transactions].each do |edited|
            idx = edited[:index].to_i
            next unless cached[:data][:transactions][idx]
            cached[:data][:transactions][idx].merge!(
              edited.permit(:description, :amount, :category, :mapped_category).to_h.symbolize_keys.compact
            )
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

      # POST /api/v1/companies/:company_id/imports/suggest_category
      def suggest_category
        description = params[:description] || ''
        amount = params[:amount] || ''
        merchant = params[:merchant] || ''

        categories = @company.chart_of_accounts.where(active: true).pluck(:name)
        return render json: { suggested_category: nil } if categories.blank?

        prompt = "What category should this transaction be?\n" \
                 "Description: #{description}\nAmount: #{amount}\nMerchant: #{merchant}\n\n" \
                 "Available categories: #{categories.join(', ')}\n\n" \
                 "Return ONLY a JSON object: {\"category\": \"CategoryName\"}"

        result = call_ai_for_category(prompt)
        suggested = begin
          JSON.parse(result)['category']
        rescue
          nil
        end

        render json: { suggested_category: suggested }
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
            { id: 'generic_csv', name: 'Generic CSV / Excel', extensions: ['.csv', '.xls', '.xlsx'], icon: '📄' },
            { id: 'bank_statement', name: 'Bank Statement (PDF)', extensions: ['.pdf'], icon: '🏦' }
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

      def upload_statement(file, content, filename)
        # Compute file hash for duplicate detection
        file_hash = Digest::MD5.hexdigest(content)
        duplicate = @company.statement_uploads.where(file_hash: file_hash).where.not(status: 'failed').order(created_at: :desc).first
        duplicate_warning = nil
        if duplicate
          txn_count = duplicate.transactions_imported || duplicate.transactions_found || 0
          duplicate_warning = "This statement was previously imported on #{duplicate.created_at.strftime('%b %d, %Y')} (#{txn_count} transactions)."
        end

        upload = @company.statement_uploads.create!(
          user: current_user,
          filename: filename,
          file_type: File.extname(filename).delete('.').downcase,
          status: 'parsing',
          file_hash: file_hash
        )

        parser = StatementParser.new(@company)
        result = parser.parse(content, filename)

        unless result[:success]
          upload.update!(status: 'failed', error_message: result[:error])
          return render json: { error: result[:error] }, status: :unprocessable_entity
        end

        upload.update!(
          status: 'parsed',
          transactions_found: result[:count],
          raw_data: { transactions: result[:transactions], account_name: result[:account_name], account_type: result[:account_type] },
          parse_notes: result[:notes]
        )

        # Store in cache so the commit step works the same way
        parsed_txns = (result[:transactions] || []).map do |t|
          {
            date: t['date'], description: t['description'], amount: t['amount'].to_f,
            category: t['suggested_category'], merchant: t['merchant'],
            mapped_category: t['suggested_category'], account_name: result[:account_name]
          }
        end

        cache_key = "import_#{@company.id}_#{SecureRandom.hex(8)}"
        Rails.cache.write(cache_key, { data: { transactions: parsed_txns }, filename: filename, statement_upload_id: upload.id }, expires_in: 1.hour)

        UsageMeter.new(@company, current_user).track('data_import', summary: "Statement: #{filename}")

        response = {
          import_key: cache_key,
          source: { source: 'bank_statement', format: File.extname(filename).delete('.'), confidence: 90 },
          summary: {
            transactions: result[:count],
            accounts: result[:account_name] ? 1 : 0,
            date_range: date_range_from(result[:transactions])
          },
          warnings: result[:notes] ? [result[:notes]] : [],
          sample_transactions: (result[:transactions] || []).first(20).map { |t|
            {
              date: t['date'], description: t['description'], amount: t['amount'],
              category: t['suggested_category'], merchant: t['merchant'],
              account: result[:account_name]
            }
          }
        }

        if duplicate_warning
          response[:duplicate_warning] = duplicate_warning
          response[:previous_upload_id] = duplicate.id
        end

        render json: response
      end

      def date_range_from(transactions)
        return nil if transactions.blank?
        dates = transactions.map { |t| t['date'] }.compact.sort
        { from: dates.first, to: dates.last }
      end

      def set_company
        @company = current_user.accessible_companies.find(params[:company_id])
      end

      def call_ai_for_category(prompt)
        api_key = Rails.application.credentials.dig(:openai, :api_key) || ENV['OPENAI_API_KEY']
        return '{}' unless api_key

        uri = URI('https://api.openai.com/v1/chat/completions')
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 15

        body = {
          model: 'gpt-4o-mini',
          messages: [
            { role: 'system', content: 'You are a bookkeeping assistant. Suggest the best category for transactions. Return ONLY valid JSON.' },
            { role: 'user', content: prompt }
          ],
          temperature: 0.2,
          max_tokens: 100,
          response_format: { type: 'json_object' }
        }

        request = Net::HTTP::Post.new(uri)
        request['Authorization'] = "Bearer #{api_key}"
        request['Content-Type'] = 'application/json'
        request.body = body.to_json

        response = http.request(request)
        data = JSON.parse(response.body)
        data.dig('choices', 0, 'message', 'content') || '{}'
      rescue => e
        Rails.logger.error("AI category suggestion failed: #{e.message}")
        '{}'
      end
    end
  end
end
