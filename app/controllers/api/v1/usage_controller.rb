module Api
  module V1
    class UsageController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!
      before_action :set_company

      # GET /api/v1/companies/:company_id/usage
      # Current billing cycle usage
      def show
        meter = UsageMeter.new(@company, current_user)
        data = meter.cycle_usage.merge(
          engagement_type: @company.engagement_type,
          monthly_fee: @company.monthly_fee,
          hourly_rate: @company.hourly_rate
        )

        # Include Clockify hours for hourly engagements
        if @company.engagement_type == 'hourly'
          hours = meter.clockify_hours
          if hours
            data[:hours] = hours
            data[:base_fee] = hours[:total_amount]
            data[:total_due] = hours[:total_amount] + (data[:overage] || 0)
          end
        else
          data[:base_fee] = @company.monthly_fee
          data[:total_due] = @company.monthly_fee + (data[:overage] || 0)
        end

        render json: data
      end

      # GET /api/v1/companies/:company_id/usage/queries
      # Recent queries log
      def queries
        queries = @company.ai_queries
          .where(user: current_user)
          .order(created_at: :desc)
          .limit(params[:limit] || 50)

        render json: queries.map { |q|
          {
            id: q.id,
            action: q.action,
            query_summary: q.query_summary,
            billed_amount: q.billed_amount,
            created_at: q.created_at
          }
        }
      end

      # GET /api/v1/companies/:company_id/usage/history
      # Monthly usage history
      def history
        months = (params[:months] || 6).to_i
        
        data = (0...months).map do |i|
          month = i.months.ago.beginning_of_month
          meter = UsageMeter.new(@company, current_user)
          meter.billing_summary(month)
        end

        render json: data
      end

      private

      def set_company
        @company = current_user.accessible_companies.find(params[:company_id])
      end
    end
  end
end
