class HomeOfficeRecord < ApplicationRecord
  belongs_to :company

  validates :tax_year, presence: true, uniqueness: { scope: :company_id }
  validates :method, presence: true, inclusion: { in: %w[simplified regular] }
  validates :office_sq_ft, numericality: { less_than_or_equal_to: 300 }, if: :simplified?

  before_save :calculate_deduction

  SIMPLIFIED_RATE = 5.00  # $5 per sq ft
  SIMPLIFIED_MAX_SQ_FT = 300  # IRS limit
  SIMPLIFIED_MAX_DEDUCTION = 1500.00

  def simplified?
    method == 'simplified'
  end

  def regular?
    method == 'regular'
  end

  def calculate_deduction
    if simplified?
      sq_ft = [office_sq_ft || 0, SIMPLIFIED_MAX_SQ_FT].min
      self.simplified_deduction = [sq_ft * SIMPLIFIED_RATE, SIMPLIFIED_MAX_DEDUCTION].min
      self.deductible_amount = simplified_deduction
    else
      self.business_use_percentage = calculate_business_use_pct if total_home_sq_ft.to_i > 0
      self.total_expenses = sum_expenses
      self.deductible_amount = (total_expenses * (business_use_percentage || 0) / 100).round(2)
    end
  end

  private

  def calculate_business_use_pct
    return 0 if total_home_sq_ft.to_i.zero?
    ((office_sq_ft.to_f / total_home_sq_ft) * 100).round(2)
  end

  def sum_expenses
    [mortgage_interest, real_estate_taxes, rent_paid, utilities,
     insurance, repairs_maintenance, depreciation, other_expenses]
      .compact.sum.round(2)
  end
end
