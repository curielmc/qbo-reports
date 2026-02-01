module Api
  module V1
    class CategorizationRulesController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!
      before_action :set_company

      # GET /api/v1/companies/:company_id/categorization_rules
      def index
        rules = @company.categorization_rules.includes(:chart_of_account).by_priority
        render json: rules.map { |r| serialize(r) }
      end

      # POST /api/v1/companies/:company_id/categorization_rules
      def create
        rule = @company.categorization_rules.build(rule_params)
        if rule.save
          render json: serialize(rule), status: :created
        else
          render json: { errors: rule.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/companies/:company_id/categorization_rules/:id
      def update
        rule = @company.categorization_rules.find(params[:id])
        if rule.update(rule_params)
          render json: serialize(rule)
        else
          render json: { errors: rule.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/companies/:company_id/categorization_rules/:id
      def destroy
        rule = @company.categorization_rules.find(params[:id])
        rule.destroy
        render json: { message: 'Rule deleted' }
      end

      # POST /api/v1/companies/:company_id/categorization_rules/run
      # Apply all active rules to uncategorized transactions
      def run
        count = CategorizationRule.auto_categorize(@company)
        render json: { message: "#{count} transactions categorized", categorized: count }
      end

      # GET /api/v1/companies/:company_id/categorization_rules/suggestions
      # AI-suggested rules based on existing categorizations
      def suggestions
        suggestions = CategorizationRule.suggest_rules(@company)
        render json: suggestions
      end

      private

      def set_company
        @company = current_user.accessible_companies.find(params[:company_id])
      end

      def rule_params
        params.require(:categorization_rule).permit(:match_type, :match_field, :match_value, :chart_of_account_id, :priority, :active)
      end

      def serialize(r)
        {
          id: r.id,
          match_type: r.match_type,
          match_field: r.match_field,
          match_value: r.match_value,
          chart_of_account_name: r.chart_of_account&.name,
          chart_of_account_id: r.chart_of_account_id,
          priority: r.priority,
          active: r.active,
          times_applied: r.times_applied,
          created_at: r.created_at
        }
      end
    end
  end
end
