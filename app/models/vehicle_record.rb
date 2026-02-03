class VehicleRecord < ApplicationRecord
  belongs_to :company

  validates :tax_year, presence: true
  validates :method, presence: true, inclusion: { in: %w[standard_mileage actual] }

  before_save :calculate_deduction

  # IRS standard mileage rates by year
  MILEAGE_RATES = {
    2024 => 0.670,  # 67.0 cents
    2025 => 0.700,  # 70.0 cents (estimate)
    2026 => 0.700   # placeholder
  }.freeze

  def standard_mileage?
    method == 'standard_mileage'
  end

  def actual?
    method == 'actual'
  end

  def calculate_deduction
    self.business_use_percentage = calculate_business_use_pct if total_miles.to_i > 0

    if standard_mileage?
      self.mileage_rate ||= MILEAGE_RATES[tax_year] || 0.670
      self.standard_mileage_deduction = (business_miles.to_i * mileage_rate).round(2)
      # Parking & tolls always fully deductible, not prorated
      self.deductible_amount = standard_mileage_deduction + (parking_tolls || 0)
    else
      self.total_actual_expenses = sum_actual_expenses
      prorated = (total_actual_expenses * (business_use_percentage || 0) / 100).round(2)
      # Parking & tolls always fully deductible
      self.deductible_amount = prorated + (parking_tolls || 0)
    end
  end

  private

  def calculate_business_use_pct
    return 0 if total_miles.to_i.zero?
    ((business_miles.to_f / total_miles) * 100).round(2)
  end

  def sum_actual_expenses
    [gas_fuel, oil_changes, repairs_maintenance, insurance, registration_fees,
     lease_payments, loan_interest, depreciation, other_expenses]
      .compact.sum.round(2)
  end
end
