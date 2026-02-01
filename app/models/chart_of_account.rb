class ChartOfAccount < ApplicationRecord
  belongs_to :household
  has_many :transactions, dependent: :nullify

  enum account_type: {
    asset: 'asset',
    liability: 'liability', 
    equity: 'equity',
    income: 'income',
    expense: 'expense'
  }

  validates :name, :account_type, presence: true
  validates :code, uniqueness: { scope: :household_id }, allow_nil: true

  # Standard Chart of Accounts templates
  def self.default_chart
    {
      assets: [
        { code: '1000', name: 'Cash & Bank Accounts' },
        { code: '1100', name: 'Checking Account' },
        { code: '1200', name: 'Savings Account' },
        { code: '1300', name: 'Investments' },
        { code: '1400', name: 'Other Assets' }
      ],
      liabilities: [
        { code: '2000', name: 'Credit Cards' },
        { code: '2100', name: 'Loans' },
        { code: '2200', name: 'Mortgages' },
        { code: '2900', name: 'Other Liabilities' }
      ],
      equity: [
        { code: '3000', name: 'Opening Balance' },
        { code: '3900', name: 'Retained Earnings' }
      ],
      income: [
        { code: '4000', name: 'Salary & Wages' },
        { code: '4100', name: 'Investment Income' },
        { code: '4200', name: 'Other Income' }
      ],
      expenses: [
        { code: '5000', name: 'Housing' },
        { code: '5100', name: 'Food & Dining' },
        { code: '5200', name: 'Transportation' },
        { code: '5300', name: 'Healthcare' },
        { code: '5400', name: 'Insurance' },
        { code: '5500', name: 'Utilities' },
        { code: '5600', name: 'Entertainment' },
        { code: '5700', name: 'Travel' },
        { code: '5800', name: 'Shopping' },
        { code: '5900', name: 'Other Expenses' }
      ]
    }
  end

  def self.setup_defaults_for(household)
    default_chart.each do |type, accounts|
      accounts.each do |attrs|
        household.chart_of_accounts.create!(
          attrs.merge(account_type: type)
        )
      end
    end
  end
end
