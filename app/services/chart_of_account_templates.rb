# Standard Chart of Accounts templates + AI-adaptive COA system

class ChartOfAccountTemplates
  # Minimal universal template that works for ANY entity
  UNIVERSAL = [
    # Income — every business has these
    { code: '4000', name: 'Revenue', type: 'income' },
    { code: '4900', name: 'Other Income', type: 'income' },

    # Expenses — universal categories
    { code: '5000', name: 'Cost of Goods Sold', type: 'expense' },
    { code: '6000', name: 'Advertising & Marketing', type: 'expense' },
    { code: '6010', name: 'Bank & Merchant Fees', type: 'expense' },
    { code: '6020', name: 'Contractors & Freelancers', type: 'expense' },
    { code: '6030', name: 'Insurance', type: 'expense' },
    { code: '6040', name: 'Interest Expense', type: 'expense' },
    { code: '6050', name: 'Legal & Professional', type: 'expense' },
    { code: '6060', name: 'Meals & Entertainment', type: 'expense' },
    { code: '6070', name: 'Office Expenses', type: 'expense' },
    { code: '6080', name: 'Payroll & Benefits', type: 'expense' },
    { code: '6090', name: 'Rent & Lease', type: 'expense' },
    { code: '6100', name: 'Software & Technology', type: 'expense' },
    { code: '6110', name: 'Supplies', type: 'expense' },
    { code: '6120', name: 'Taxes & Licenses', type: 'expense' },
    { code: '6130', name: 'Travel', type: 'expense' },
    { code: '6140', name: 'Utilities', type: 'expense' },
    { code: '6150', name: 'Vehicle & Transportation', type: 'expense' },
    { code: '6900', name: 'Miscellaneous', type: 'expense' },

    # Assets
    { code: '1000', name: 'Cash & Bank Accounts', type: 'asset' },
    { code: '1100', name: 'Accounts Receivable', type: 'asset' },
    { code: '1500', name: 'Fixed Assets', type: 'asset' },

    # Liabilities
    { code: '2000', name: 'Accounts Payable', type: 'liability' },
    { code: '2100', name: 'Credit Cards', type: 'liability' },
    { code: '2200', name: 'Loans', type: 'liability' },
    { code: '2300', name: 'Payroll Liabilities', type: 'liability' },

    # Equity
    { code: '3000', name: "Owner's Equity", type: 'equity' },
    { code: '3100', name: 'Retained Earnings', type: 'equity' },
  ]

  def self.apply_universal(company)
    UNIVERSAL.each do |entry|
      company.chart_of_accounts.find_or_create_by!(code: entry[:code]) do |coa|
        coa.name = entry[:name]
        coa.account_type = entry[:type]
        coa.active = true
      end
    end
  end

  # Get the next available code for a type
  def self.next_code(company, account_type)
    prefix = case account_type
    when 'asset' then '1'
    when 'liability' then '2'
    when 'equity' then '3'
    when 'income' then '4'
    when 'expense' then '6'
    else '9'
    end

    existing = company.chart_of_accounts
      .where(account_type: account_type)
      .pluck(:code)
      .compact
      .select { |c| c.start_with?(prefix) }
      .map(&:to_i)
      .max || (prefix.to_i * 1000 - 10)

    (existing + 10).to_s
  end
end
