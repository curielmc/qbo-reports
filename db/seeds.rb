# Standard Chart of Accounts template for new companies
STANDARD_COA = [
  # Income
  { code: '4000', name: 'Revenue', account_type: 'income' },
  { code: '4010', name: 'Consulting Income', account_type: 'income' },
  { code: '4020', name: 'Service Income', account_type: 'income' },
  { code: '4030', name: 'Product Sales', account_type: 'income' },
  { code: '4900', name: 'Other Income', account_type: 'income' },
  { code: '4910', name: 'Interest Income', account_type: 'income' },

  # Expenses
  { code: '5000', name: 'Cost of Goods Sold', account_type: 'expense' },
  { code: '6000', name: 'Advertising & Marketing', account_type: 'expense' },
  { code: '6010', name: 'Bank Fees & Charges', account_type: 'expense' },
  { code: '6020', name: 'Dues & Subscriptions', account_type: 'expense' },
  { code: '6030', name: 'Equipment & Hardware', account_type: 'expense' },
  { code: '6040', name: 'Insurance', account_type: 'expense' },
  { code: '6050', name: 'Interest Expense', account_type: 'expense' },
  { code: '6060', name: 'Legal & Professional Fees', account_type: 'expense' },
  { code: '6070', name: 'Meals & Entertainment', account_type: 'expense' },
  { code: '6080', name: 'Office Supplies', account_type: 'expense' },
  { code: '6090', name: 'Payroll', account_type: 'expense' },
  { code: '6100', name: 'Payroll Taxes', account_type: 'expense' },
  { code: '6110', name: 'Rent', account_type: 'expense' },
  { code: '6120', name: 'Repairs & Maintenance', account_type: 'expense' },
  { code: '6130', name: 'Software & SaaS', account_type: 'expense' },
  { code: '6140', name: 'Taxes & Licenses', account_type: 'expense' },
  { code: '6150', name: 'Telephone & Internet', account_type: 'expense' },
  { code: '6160', name: 'Travel', account_type: 'expense' },
  { code: '6170', name: 'Utilities', account_type: 'expense' },
  { code: '6180', name: 'Vehicle Expenses', account_type: 'expense' },
  { code: '6190', name: 'Contractor Payments', account_type: 'expense' },
  { code: '6900', name: 'Miscellaneous Expense', account_type: 'expense' },

  # Assets
  { code: '1000', name: 'Cash & Bank', account_type: 'asset' },
  { code: '1100', name: 'Accounts Receivable', account_type: 'asset' },
  { code: '1200', name: 'Inventory', account_type: 'asset' },
  { code: '1300', name: 'Prepaid Expenses', account_type: 'asset' },
  { code: '1500', name: 'Fixed Assets', account_type: 'asset' },
  { code: '1510', name: 'Accumulated Depreciation', account_type: 'asset' },

  # Liabilities
  { code: '2000', name: 'Accounts Payable', account_type: 'liability' },
  { code: '2100', name: 'Credit Cards', account_type: 'liability' },
  { code: '2200', name: 'Payroll Liabilities', account_type: 'liability' },
  { code: '2300', name: 'Sales Tax Payable', account_type: 'liability' },
  { code: '2400', name: 'Loans Payable', account_type: 'liability' },

  # Equity
  { code: '3000', name: "Owner's Equity", account_type: 'equity' },
  { code: '3100', name: "Owner's Draw", account_type: 'equity' },
  { code: '3200', name: 'Retained Earnings', account_type: 'equity' },
]

# Create admin user
admin = User.find_or_create_by!(email: 'admin@ecfobooks.com') do |u|
  u.first_name = 'Admin'
  u.last_name = 'User'
  u.password = 'ecfobooks2026!'
  u.role = :executive
end

puts "Created admin user: admin@ecfobooks.com / ecfobooks2026!"

# Create demo company
demo = Company.find_or_create_by!(name: 'Demo Company')
CompanyUser.find_or_create_by!(user: admin, company: demo) do |cu|
  cu.role = 'executive'
end

# Create demo admin user
admin = User.find_or_create_by!(email: 'martin@myecfo.com') do |u|
  u.first_name = 'Martin'
  u.last_name = 'Curiel'
  u.password = 'ecfobooks2026!'
  u.role = 'executive'
end

# Create demo company
demo = Company.find_or_create_by!(name: 'Demo Company') do |c|
  c.engagement_type = 'flat_fee'
  c.monthly_fee = 500
  c.ai_credit_cents = 10000
end

# Link admin to company
CompanyUser.find_or_create_by!(user: admin, company: demo) do |cu|
  cu.role = 'owner'
end

# Apply universal COA template
ChartOfAccountTemplates.apply_universal(demo)

puts "Created demo company with #{demo.chart_of_accounts.count} chart of accounts entries (universal template)"
