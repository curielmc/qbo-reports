class JournalTemplate < ApplicationRecord
  belongs_to :company

  SYSTEM_TEMPLATES = [
    {
      name: 'Depreciation — Straight Line',
      description: 'Monthly depreciation entry for a fixed asset',
      entry_type: 'depreciation',
      lines: [
        { account_name: 'Depreciation Expense', side: 'debit', memo: 'Monthly depreciation' },
        { account_name: 'Accumulated Depreciation', side: 'credit', memo: 'Monthly depreciation' }
      ]
    },
    {
      name: 'Accrued Expense',
      description: 'Record expense that has been incurred but not yet paid',
      entry_type: 'accrual',
      lines: [
        { account_name: '(Expense Account)', side: 'debit', memo: 'Accrued expense' },
        { account_name: 'Accrued Liabilities', side: 'credit', memo: 'Accrued expense' }
      ]
    },
    {
      name: 'Prepaid Expense Amortization',
      description: 'Recognize portion of prepaid expense in current period',
      entry_type: 'adjusting',
      lines: [
        { account_name: '(Expense Account)', side: 'debit', memo: 'Prepaid amortization' },
        { account_name: 'Prepaid Expenses', side: 'credit', memo: 'Prepaid amortization' }
      ]
    },
    {
      name: 'Deferred Revenue Recognition',
      description: 'Recognize earned revenue from deferred/unearned revenue',
      entry_type: 'adjusting',
      lines: [
        { account_name: 'Unearned Revenue', side: 'debit', memo: 'Revenue recognition' },
        { account_name: 'Revenue', side: 'credit', memo: 'Revenue recognition' }
      ]
    },
    {
      name: 'Bad Debt Write-Off',
      description: 'Write off uncollectible accounts receivable',
      entry_type: 'adjusting',
      lines: [
        { account_name: 'Bad Debt Expense', side: 'debit', memo: 'Bad debt write-off' },
        { account_name: 'Accounts Receivable', side: 'credit', memo: 'Bad debt write-off' }
      ]
    },
    {
      name: 'Owner Distribution',
      description: 'Record owner draw or distribution',
      entry_type: 'standard',
      lines: [
        { account_name: "Owner's Draw", side: 'debit', memo: 'Distribution' },
        { account_name: 'Cash & Bank Accounts', side: 'credit', memo: 'Distribution' }
      ]
    },
    {
      name: 'Payroll Accrual',
      description: 'Accrue payroll expense at period end',
      entry_type: 'accrual',
      lines: [
        { account_name: 'Payroll & Benefits', side: 'debit', memo: 'Payroll accrual' },
        { account_name: 'Payroll Liabilities', side: 'credit', memo: 'Payroll accrual' }
      ]
    },
    {
      name: 'Loan Payment Split',
      description: 'Split loan payment into principal and interest',
      entry_type: 'standard',
      lines: [
        { account_name: 'Loans', side: 'debit', memo: 'Principal portion' },
        { account_name: 'Interest Expense', side: 'debit', memo: 'Interest portion' },
        { account_name: 'Cash & Bank Accounts', side: 'credit', memo: 'Total payment' }
      ]
    }
  ].freeze

  def self.seed_system_templates(company)
    SYSTEM_TEMPLATES.each do |tmpl|
      company.journal_templates.find_or_create_by!(name: tmpl[:name], system_template: true) do |t|
        t.description = tmpl[:description]
        t.entry_type = tmpl[:entry_type]
        t.lines = tmpl[:lines]
      end
    end
  end
end
