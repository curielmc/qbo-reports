class Company < ApplicationRecord
  has_many :company_users, dependent: :destroy
  has_many :users, through: :company_users
  has_many :advisors, -> { where(company_users: { role: 'advisor' }) }, 
           through: :company_users, source: :user
  has_many :clients, -> { where(company_users: { role: 'client' }) }, 
           through: :company_users, source: :user
  
  has_many :accounts, dependent: :destroy
  has_many :plaid_items, dependent: :destroy
  has_many :account_transactions, through: :accounts
  has_many :chart_of_accounts, dependent: :destroy
  has_many :categorization_rules, dependent: :destroy
  has_many :chat_messages, dependent: :destroy
  has_many :journal_entries, dependent: :destroy
  has_many :statement_uploads, dependent: :destroy
  has_many :ai_queries, dependent: :destroy
  has_many :reconciliations, dependent: :destroy
  has_many :receipts, dependent: :destroy
  has_many :invitations, dependent: :destroy
  has_many :audit_logs, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :bookkeeper_tasks, dependent: :destroy
  has_many :month_end_closes, dependent: :destroy
  has_many :recurring_entries, dependent: :destroy
  has_many :journal_templates, dependent: :destroy
  has_many :api_keys, dependent: :destroy
  has_many :box_imported_files, dependent: :destroy
  has_many :box_sync_jobs, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :company_comments, -> { where(commentable_type: 'Company') },
           class_name: 'Comment', foreign_key: 'company_id'

  validates :name, presence: true

  # Every new company gets the universal Chart of Accounts
  after_create :apply_default_coa

  private

  def apply_default_coa
    ChartOfAccountTemplates.apply_universal(self) if chart_of_accounts.empty?
  end
end
