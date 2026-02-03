module Api
  module V1
    class ScheduleCController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!
      before_action :set_company

      # GET /api/v1/companies/:company_id/schedule_c/home_office
      def home_office_index
        records = @company.home_office_records.order(tax_year: :desc)
        render json: records
      end

      # GET /api/v1/companies/:company_id/schedule_c/home_office/:tax_year
      def home_office_show
        record = @company.home_office_records.find_by(tax_year: params[:tax_year])
        render json: record || { tax_year: params[:tax_year].to_i, method: 'simplified' }
      end

      # POST/PUT /api/v1/companies/:company_id/schedule_c/home_office
      def home_office_save
        record = @company.home_office_records.find_or_initialize_by(tax_year: params[:tax_year])
        if record.update(home_office_params)
          render json: record
        else
          render json: { errors: record.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/companies/:company_id/schedule_c/vehicles
      def vehicles_index
        records = @company.vehicle_records.order(tax_year: :desc, created_at: :asc)
        render json: records
      end

      # POST /api/v1/companies/:company_id/schedule_c/vehicles
      def vehicle_save
        if params[:id].present?
          record = @company.vehicle_records.find(params[:id])
          record.update!(vehicle_params)
        else
          record = @company.vehicle_records.create!(vehicle_params)
        end
        render json: record
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      # DELETE /api/v1/companies/:company_id/schedule_c/vehicles/:id
      def vehicle_destroy
        @company.vehicle_records.find(params[:id]).destroy!
        render json: { success: true }
      end

      # GET /api/v1/companies/:company_id/schedule_c/summary/:tax_year
      def summary
        tax_year = params[:tax_year].to_i
        home_office = @company.home_office_records.find_by(tax_year: tax_year)
        vehicles = @company.vehicle_records.where(tax_year: tax_year)

        render json: {
          tax_year: tax_year,
          home_office: home_office,
          home_office_deduction: home_office&.deductible_amount || 0,
          vehicles: vehicles,
          total_vehicle_deduction: vehicles.sum(:deductible_amount),
          total_schedule_c_additions: (home_office&.deductible_amount || 0) + vehicles.sum(:deductible_amount)
        }
      end

      private

      def set_company
        @company = current_user.accessible_companies.find(params[:company_id])
      end

      def home_office_params
        params.permit(:tax_year, :method, :total_home_sq_ft, :office_sq_ft,
          :mortgage_interest, :real_estate_taxes, :rent_paid, :utilities,
          :insurance, :repairs_maintenance, :depreciation, :other_expenses, :notes)
      end

      def vehicle_params
        params.permit(:tax_year, :vehicle_description, :date_placed_in_service, :method,
          :total_miles, :business_miles, :commuting_miles, :personal_miles,
          :gas_fuel, :oil_changes, :repairs_maintenance, :insurance, :registration_fees,
          :lease_payments, :loan_interest, :depreciation, :parking_tolls, :other_expenses, :notes)
      end
    end
  end
end
