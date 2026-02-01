module Api
  module V1
    module Admin
      class BillingController < AdminController
        # GET /api/v1/admin/billing
        # Overview of all companies' billing
        def index
          companies = Company.where(billing_active: true).order(:name)
          
          render json: companies.map { |c|
            meter = UsageMeter.new(c, current_user)
            usage = meter.cycle_usage

            {
              id: c.id,
              name: c.name,
              engagement_type: c.engagement_type,
              monthly_fee: c.monthly_fee,
              hourly_rate: c.hourly_rate,
              ai_credit: c.ai_credit_cents / 100.0,
              ai_credit_used: c.ai_credit_used_cents / 100.0,
              credit_remaining: usage[:credit_remaining],
              total_queries: usage[:total_queries],
              overage: usage[:overage],
              total_due: c.monthly_fee + usage[:overage]
            }
          }
        end

        # GET /api/v1/admin/billing/:company_id
        # Detailed billing for a specific company
        def show
          company = Company.find(params[:company_id])
          meter = UsageMeter.new(company, current_user)

          render json: {
            company: company.name,
            engagement_type: company.engagement_type,
            monthly_fee: company.monthly_fee,
            current_cycle: meter.cycle_usage,
            billing_summary: meter.billing_summary
          }
        end

        # PUT /api/v1/admin/billing/:company_id
        # Update billing settings
        def update
          company = Company.find(params[:company_id])
          company.update!(billing_params)
          render json: { message: 'Billing updated' }
        end

        # POST /api/v1/admin/billing/:company_id/reset_credit
        # Reset credit for new billing cycle
        def reset_credit
          company = Company.find(params[:company_id])
          company.update!(
            ai_credit_used_cents: 0,
            billing_cycle_start: Date.current
          )
          render json: { message: "Credit reset to $#{company.ai_credit_cents / 100.0}" }
        end

        private

        def billing_params
          params.require(:billing).permit(
            :engagement_type, :monthly_fee, :hourly_rate,
            :ai_credit_cents, :per_query_cents, :billing_active,
            :clockify_project_id, :clockify_client_id
          )
        end
      end
    end
  end
end
