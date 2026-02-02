module Api
  module V1
    class ReceiptsController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!
      before_action :set_company

      # POST /api/v1/companies/:company_id/receipts
      def create
        file = params[:file]
        return render json: { error: 'File required' }, status: :unprocessable_entity unless file

        # Store file (ActiveStorage or S3 in production)
        file_url = store_file(file)

        receipt = @company.receipts.create!(
          user: current_user,
          file_url: file_url,
          filename: file.original_filename,
          content_type: file.content_type,
          status: 'pending'
        )

        # Parse with AI
        parser = ReceiptParser.new(@company)
        parsed = parser.parse(file_url: file_url, content_type: file.content_type)

        receipt.update!(
          vendor: parsed[:vendor],
          amount: parsed[:amount],
          receipt_date: parsed[:receipt_date],
          description: parsed[:description],
          raw_text: parsed[:raw_text],
          ai_data: parsed
        )

        # Try to match
        receipt.auto_match!

        # Track usage
        UsageMeter.new(@company, current_user).track('receipt_parse', summary: "Receipt: #{parsed[:vendor]}")

        render json: {
          receipt: format_receipt(receipt),
          matched_transaction: receipt.account_transaction ? format_transaction(receipt.account_transaction) : nil
        }
      end

      # GET /api/v1/companies/:company_id/receipts
      def index
        receipts = @company.receipts.order(created_at: :desc).limit(params[:limit] || 50)
        receipts = receipts.where(status: params[:status]) if params[:status]

        render json: receipts.map { |r| format_receipt(r) }
      end

      # PATCH /api/v1/companies/:company_id/receipts/:id/match
      def match
        receipt = @company.receipts.find(params[:id])
        transaction = @company.account_transactions.find(params[:transaction_id])

        receipt.match_to!(transaction)

        AuditLog.record!(
          company: @company, user: current_user,
          action: 'receipt_matched', resource: receipt,
          changes: { transaction_id: transaction.id }
        )

        render json: { receipt: format_receipt(receipt) }
      end

      private

      def set_company
        @company = current_user.accessible_companies.find(params[:company_id])
      end

      def store_file(file)
        # For now, store locally. In production, use S3/ActiveStorage
        dir = Rails.root.join('storage', 'receipts', @company.id.to_s)
        FileUtils.mkdir_p(dir)
        path = dir.join("#{SecureRandom.hex(8)}_#{file.original_filename}")
        File.open(path, 'wb') { |f| f.write(file.read) }
        path.to_s
      end

      def format_receipt(r)
        {
          id: r.id,
          vendor: r.vendor,
          amount: r.amount,
          date: r.receipt_date,
          description: r.description,
          status: r.status,
          filename: r.filename,
          matched_transaction_id: r.transaction_id,
          created_at: r.created_at
        }
      end

      def format_transaction(t)
        {
          id: t.id,
          date: t.date,
          description: t.description,
          amount: t.amount,
          merchant: t.merchant_name
        }
      end
    end
  end
end
