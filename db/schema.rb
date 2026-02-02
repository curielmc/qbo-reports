# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2026_02_02_220004) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "name", null: false
    t.string "account_type", null: false
    t.string "plaid_account_id"
    t.bigint "plaid_item_id"
    t.decimal "current_balance", precision: 15, scale: 2, default: "0.0"
    t.decimal "available_balance", precision: 15, scale: 2, default: "0.0"
    t.string "mask"
    t.string "official_name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "account_subtype"
    t.index ["company_id", "account_type"], name: "index_accounts_on_company_id_and_account_type"
    t.index ["company_id"], name: "index_accounts_on_company_id"
    t.index ["plaid_account_id"], name: "index_accounts_on_plaid_account_id", unique: true
  end

  create_table "ai_queries", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "user_id", null: false
    t.string "action", null: false
    t.integer "input_tokens", default: 0
    t.integer "output_tokens", default: 0
    t.decimal "cost", precision: 10, scale: 6, default: "0.0"
    t.decimal "billed_amount", precision: 10, scale: 2, default: "0.0"
    t.text "query_summary"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["company_id", "action"], name: "index_ai_queries_on_company_id_and_action"
    t.index ["company_id", "created_at"], name: "index_ai_queries_on_company_id_and_created_at"
    t.index ["company_id"], name: "index_ai_queries_on_company_id"
    t.index ["user_id"], name: "index_ai_queries_on_user_id"
  end

  create_table "api_keys", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "company_id", null: false
    t.string "token_digest", null: false
    t.string "prefix", limit: 8, null: false
    t.string "name", null: false
    t.string "permissions", default: [], array: true
    t.boolean "active", default: true, null: false
    t.datetime "expires_at"
    t.datetime "last_used_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["company_id"], name: "index_api_keys_on_company_id"
    t.index ["prefix"], name: "index_api_keys_on_prefix"
    t.index ["token_digest"], name: "index_api_keys_on_token_digest", unique: true
    t.index ["user_id", "company_id"], name: "index_api_keys_on_user_id_and_company_id"
    t.index ["user_id"], name: "index_api_keys_on_user_id"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "user_id", null: false
    t.string "action", null: false
    t.string "resource_type"
    t.bigint "resource_id"
    t.jsonb "changes_made"
    t.string "ip_address"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["company_id", "created_at"], name: "index_audit_logs_on_company_id_and_created_at"
    t.index ["company_id"], name: "index_audit_logs_on_company_id"
    t.index ["resource_type", "resource_id"], name: "index_audit_logs_on_resource_type_and_resource_id"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "bookkeeper_tasks", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "assigned_to_id"
    t.string "task_type", null: false
    t.string "priority", default: "normal"
    t.string "status", default: "pending"
    t.string "title", null: false
    t.text "description"
    t.jsonb "metadata"
    t.integer "estimated_minutes", default: 5
    t.datetime "due_date"
    t.datetime "completed_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["assigned_to_id", "status"], name: "index_bookkeeper_tasks_on_assigned_to_id_and_status"
    t.index ["assigned_to_id"], name: "index_bookkeeper_tasks_on_assigned_to_id"
    t.index ["company_id", "status"], name: "index_bookkeeper_tasks_on_company_id_and_status"
    t.index ["company_id"], name: "index_bookkeeper_tasks_on_company_id"
    t.index ["priority", "status"], name: "index_bookkeeper_tasks_on_priority_and_status"
  end

  create_table "box_imported_files", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "box_file_id", null: false
    t.string "filename"
    t.string "box_folder_path"
    t.bigint "statement_upload_id"
    t.string "status", default: "imported"
    t.text "error_message"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["company_id", "box_file_id"], name: "index_box_imported_files_on_company_id_and_box_file_id", unique: true
    t.index ["company_id"], name: "index_box_imported_files_on_company_id"
    t.index ["statement_upload_id"], name: "index_box_imported_files_on_statement_upload_id"
  end

  create_table "box_sync_jobs", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "user_id", null: false
    t.string "status", default: "pending"
    t.integer "total_files", default: 0
    t.integer "processed_files", default: 0
    t.integer "imported_files", default: 0
    t.integer "skipped_files", default: 0
    t.integer "failed_files", default: 0
    t.text "current_file"
    t.text "error_message"
    t.jsonb "details", default: {}
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["company_id"], name: "index_box_sync_jobs_on_company_id"
    t.index ["user_id"], name: "index_box_sync_jobs_on_user_id"
  end

  create_table "categorization_rules", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "chart_of_account_id", null: false
    t.string "match_type", default: "contains", null: false
    t.string "match_field", default: "description", null: false
    t.string "match_value", null: false
    t.integer "priority", default: 0
    t.boolean "active", default: true
    t.integer "times_applied", default: 0
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["chart_of_account_id"], name: "index_categorization_rules_on_chart_of_account_id"
    t.index ["company_id", "priority"], name: "index_categorization_rules_on_company_id_and_priority"
    t.index ["company_id"], name: "index_categorization_rules_on_company_id"
  end

  create_table "chart_of_accounts", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "code"
    t.string "name", null: false
    t.string "account_type", null: false
    t.boolean "active", default: true
    t.string "parent_code"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["company_id", "account_type"], name: "index_chart_of_accounts_on_company_id_and_account_type"
    t.index ["company_id", "code"], name: "index_chart_of_accounts_on_company_id_and_code", unique: true
    t.index ["company_id"], name: "index_chart_of_accounts_on_company_id"
  end

  create_table "chat_messages", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "company_id", null: false
    t.string "role", default: "user", null: false
    t.text "content", null: false
    t.jsonb "metadata", default: {}
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["company_id", "created_at"], name: "index_chat_messages_on_company_id_and_created_at"
    t.index ["company_id"], name: "index_chat_messages_on_company_id"
    t.index ["user_id"], name: "index_chat_messages_on_user_id"
  end

  create_table "companies", force: :cascade do |t|
    t.string "name", null: false
    t.string "external_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "engagement_type", default: "flat_fee"
    t.decimal "monthly_fee", precision: 10, scale: 2, default: "0.0"
    t.decimal "hourly_rate", precision: 10, scale: 2, default: "0.0"
    t.integer "ai_credit_cents", default: 10000
    t.integer "ai_credit_used_cents", default: 0
    t.integer "per_query_cents", default: 5
    t.date "billing_cycle_start"
    t.boolean "billing_active", default: true
    t.string "clockify_project_id"
    t.string "clockify_client_id"
    t.string "box_folder_url"
    t.string "box_developer_token"
    t.string "box_folder_id"
    t.index ["external_id"], name: "index_companies_on_external_id", unique: true
  end

  create_table "company_users", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "user_id", null: false
    t.string "role", default: "client", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["company_id", "role"], name: "index_company_users_on_company_id_and_role"
    t.index ["company_id", "user_id"], name: "index_company_users_on_company_id_and_user_id", unique: true
    t.index ["company_id"], name: "index_company_users_on_company_id"
    t.index ["user_id"], name: "index_company_users_on_user_id"
  end

  create_table "invitations", force: :cascade do |t|
    t.string "email", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "role", default: "client", null: false
    t.string "token", null: false
    t.bigint "company_id"
    t.bigint "invited_by_id"
    t.datetime "accepted_at"
    t.datetime "expires_at", null: false
    t.text "personal_message"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "status", default: "pending"
    t.index ["company_id", "email"], name: "index_invitations_on_company_id_and_email"
    t.index ["company_id"], name: "index_invitations_on_company_id"
    t.index ["email"], name: "index_invitations_on_email"
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
    t.index ["token"], name: "index_invitations_on_token", unique: true
  end

  create_table "journal_entries", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "transaction_id"
    t.date "entry_date", null: false
    t.string "memo"
    t.string "source", default: "auto"
    t.boolean "posted", default: true
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "entry_type", default: "standard"
    t.string "reference_number"
    t.bigint "approved_by_id"
    t.datetime "approved_at"
    t.boolean "reversed", default: false
    t.bigint "reversing_entry_id"
    t.bigint "recurring_template_id"
    t.index ["company_id", "entry_date"], name: "index_journal_entries_on_company_id_and_entry_date"
    t.index ["company_id"], name: "index_journal_entries_on_company_id"
    t.index ["entry_type"], name: "index_journal_entries_on_entry_type"
    t.index ["reference_number"], name: "index_journal_entries_on_reference_number"
    t.index ["transaction_id"], name: "index_journal_entries_on_transaction_id"
  end

  create_table "journal_lines", force: :cascade do |t|
    t.bigint "journal_entry_id", null: false
    t.bigint "chart_of_account_id", null: false
    t.decimal "debit", precision: 15, scale: 2, default: "0.0"
    t.decimal "credit", precision: 15, scale: 2, default: "0.0"
    t.string "memo"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["chart_of_account_id", "created_at"], name: "index_journal_lines_on_chart_of_account_id_and_created_at"
    t.index ["chart_of_account_id"], name: "index_journal_lines_on_chart_of_account_id"
    t.index ["journal_entry_id"], name: "index_journal_lines_on_journal_entry_id"
  end

  create_table "journal_templates", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "entry_type", default: "adjusting"
    t.jsonb "lines"
    t.boolean "system_template", default: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["company_id"], name: "index_journal_templates_on_company_id"
  end

  create_table "month_end_closes", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "user_id", null: false
    t.date "period", null: false
    t.string "status", default: "open"
    t.jsonb "checklist"
    t.text "notes"
    t.datetime "closed_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["company_id", "period"], name: "index_month_end_closes_on_company_id_and_period", unique: true
    t.index ["company_id"], name: "index_month_end_closes_on_company_id"
    t.index ["user_id"], name: "index_month_end_closes_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "user_id", null: false
    t.string "notification_type"
    t.string "title"
    t.text "body"
    t.boolean "read", default: false
    t.jsonb "data"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["company_id"], name: "index_notifications_on_company_id"
    t.index ["user_id", "read"], name: "index_notifications_on_user_id_and_read"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "plaid_items", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "access_token", null: false
    t.string "item_id", null: false
    t.string "institution_id"
    t.string "institution_name"
    t.string "status", default: "active", null: false
    t.string "transaction_cursor"
    t.datetime "last_synced_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["company_id"], name: "index_plaid_items_on_company_id"
    t.index ["item_id"], name: "index_plaid_items_on_item_id", unique: true
    t.index ["status"], name: "index_plaid_items_on_status"
  end

  create_table "receipts", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "user_id", null: false
    t.bigint "transaction_id"
    t.string "file_url", null: false
    t.string "filename"
    t.string "content_type"
    t.string "status", default: "pending"
    t.string "vendor"
    t.decimal "amount", precision: 15, scale: 2
    t.date "receipt_date"
    t.text "description"
    t.text "raw_text"
    t.jsonb "ai_data"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["company_id", "receipt_date"], name: "index_receipts_on_company_id_and_receipt_date"
    t.index ["company_id", "status"], name: "index_receipts_on_company_id_and_status"
    t.index ["company_id"], name: "index_receipts_on_company_id"
    t.index ["transaction_id"], name: "index_receipts_on_transaction_id"
    t.index ["user_id"], name: "index_receipts_on_user_id"
  end

  create_table "reconciliations", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "account_id", null: false
    t.bigint "user_id", null: false
    t.date "statement_date", null: false
    t.decimal "statement_balance", precision: 15, scale: 2, null: false
    t.decimal "book_balance", precision: 15, scale: 2
    t.decimal "difference", precision: 15, scale: 2, default: "0.0"
    t.string "status", default: "in_progress"
    t.text "notes"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "source", default: "manual", null: false
    t.bigint "statement_upload_id"
    t.index ["account_id"], name: "index_reconciliations_on_account_id"
    t.index ["company_id", "account_id", "statement_date"], name: "idx_reconciliations_company_account_date"
    t.index ["company_id"], name: "index_reconciliations_on_company_id"
    t.index ["statement_upload_id"], name: "index_reconciliations_on_statement_upload_id"
    t.index ["user_id"], name: "index_reconciliations_on_user_id"
  end

  create_table "recurring_entries", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "created_by_id", null: false
    t.string "name", null: false
    t.text "memo"
    t.string "frequency", default: "monthly"
    t.date "start_date"
    t.date "end_date"
    t.date "next_run_date"
    t.boolean "active", default: true
    t.boolean "auto_post", default: false
    t.jsonb "lines"
    t.integer "times_run", default: 0
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["company_id", "next_run_date"], name: "index_recurring_entries_on_company_id_and_next_run_date"
    t.index ["company_id"], name: "index_recurring_entries_on_company_id"
    t.index ["created_by_id"], name: "index_recurring_entries_on_created_by_id"
  end

  create_table "statement_uploads", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "account_id"
    t.bigint "user_id", null: false
    t.string "filename", null: false
    t.string "file_type"
    t.string "status", default: "pending"
    t.integer "transactions_found", default: 0
    t.integer "transactions_imported", default: 0
    t.integer "transactions_categorized", default: 0
    t.text "parse_notes"
    t.text "error_message"
    t.jsonb "raw_data", default: {}
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "source", default: "web", null: false
    t.string "parser_engine"
    t.bigint "api_key_id"
    t.string "file_hash"
    t.index ["account_id"], name: "index_statement_uploads_on_account_id"
    t.index ["api_key_id"], name: "index_statement_uploads_on_api_key_id"
    t.index ["company_id", "file_hash"], name: "index_statement_uploads_on_company_id_and_file_hash"
    t.index ["company_id"], name: "index_statement_uploads_on_company_id"
    t.index ["user_id"], name: "index_statement_uploads_on_user_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "chart_of_account_id"
    t.string "plaid_transaction_id"
    t.string "name"
    t.text "description"
    t.decimal "amount", precision: 15, scale: 2, null: false
    t.string "currency_code", default: "USD"
    t.date "date", null: false
    t.datetime "datetime"
    t.boolean "pending", default: false
    t.string "transaction_type"
    t.string "payment_channel"
    t.string "merchant_name"
    t.jsonb "plaid_raw_data"
    t.string "categorization_source", default: "manual"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "category"
    t.string "subcategory"
    t.string "reconciliation_status", default: "uncleared"
    t.bigint "reconciliation_id"
    t.index ["account_id", "date"], name: "index_transactions_on_account_id_and_date"
    t.index ["account_id"], name: "index_transactions_on_account_id"
    t.index ["chart_of_account_id", "date"], name: "index_transactions_on_chart_of_account_id_and_date"
    t.index ["chart_of_account_id"], name: "index_transactions_on_chart_of_account_id"
    t.index ["date"], name: "index_transactions_on_date"
    t.index ["plaid_transaction_id"], name: "index_transactions_on_plaid_transaction_id", unique: true
    t.index ["reconciliation_id"], name: "index_transactions_on_reconciliation_id"
    t.index ["reconciliation_status"], name: "index_transactions_on_reconciliation_status"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "role", default: "client", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.datetime "last_sign_in_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "accounts", "companies"
  add_foreign_key "accounts", "plaid_items"
  add_foreign_key "ai_queries", "companies"
  add_foreign_key "ai_queries", "users"
  add_foreign_key "api_keys", "companies"
  add_foreign_key "api_keys", "users"
  add_foreign_key "audit_logs", "companies"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "bookkeeper_tasks", "companies"
  add_foreign_key "bookkeeper_tasks", "users", column: "assigned_to_id"
  add_foreign_key "box_imported_files", "companies"
  add_foreign_key "box_imported_files", "statement_uploads"
  add_foreign_key "box_sync_jobs", "companies"
  add_foreign_key "box_sync_jobs", "users"
  add_foreign_key "categorization_rules", "chart_of_accounts"
  add_foreign_key "categorization_rules", "companies"
  add_foreign_key "chart_of_accounts", "companies"
  add_foreign_key "chat_messages", "companies"
  add_foreign_key "chat_messages", "users"
  add_foreign_key "company_users", "companies"
  add_foreign_key "company_users", "users"
  add_foreign_key "invitations", "companies"
  add_foreign_key "invitations", "users", column: "invited_by_id"
  add_foreign_key "journal_entries", "companies"
  add_foreign_key "journal_entries", "transactions"
  add_foreign_key "journal_lines", "chart_of_accounts"
  add_foreign_key "journal_lines", "journal_entries"
  add_foreign_key "journal_templates", "companies"
  add_foreign_key "month_end_closes", "companies"
  add_foreign_key "month_end_closes", "users"
  add_foreign_key "notifications", "companies"
  add_foreign_key "notifications", "users"
  add_foreign_key "plaid_items", "companies"
  add_foreign_key "receipts", "companies"
  add_foreign_key "receipts", "transactions"
  add_foreign_key "receipts", "users"
  add_foreign_key "reconciliations", "accounts"
  add_foreign_key "reconciliations", "companies"
  add_foreign_key "reconciliations", "statement_uploads"
  add_foreign_key "reconciliations", "users"
  add_foreign_key "recurring_entries", "companies"
  add_foreign_key "recurring_entries", "users", column: "created_by_id"
  add_foreign_key "statement_uploads", "accounts"
  add_foreign_key "statement_uploads", "api_keys"
  add_foreign_key "statement_uploads", "companies"
  add_foreign_key "statement_uploads", "users"
  add_foreign_key "transactions", "accounts"
  add_foreign_key "transactions", "chart_of_accounts"
  add_foreign_key "transactions", "reconciliations"
end
