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

ActiveRecord::Schema.define(version: 2026_02_01_000006) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "name", null: false
    t.string "account_type", null: false
    t.string "plaid_account_id"
    t.string "plaid_item_id"
    t.decimal "current_balance", precision: 15, scale: 2, default: "0.0"
    t.decimal "available_balance", precision: 15, scale: 2, default: "0.0"
    t.string "mask"
    t.string "official_name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["company_id", "account_type"], name: "index_accounts_on_company_id_and_account_type"
    t.index ["company_id"], name: "index_accounts_on_company_id"
    t.index ["plaid_account_id"], name: "index_accounts_on_plaid_account_id", unique: true
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

  create_table "company_users", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "user_id", null: false
    t.string "role", default: "client", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["company_id", "user_id"], name: "index_company_users_on_company_id_and_user_id", unique: true
    t.index ["company_id"], name: "index_company_users_on_company_id"
    t.index ["user_id"], name: "index_company_users_on_user_id"
  end

  create_table "companies", force: :cascade do |t|
    t.string "name", null: false
    t.string "external_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["external_id"], name: "index_companies_on_external_id", unique: true
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
    t.index ["account_id", "date"], name: "index_transactions_on_account_id_and_date"
    t.index ["account_id"], name: "index_transactions_on_account_id"
    t.index ["chart_of_account_id", "date"], name: "index_transactions_on_chart_of_account_id_and_date"
    t.index ["chart_of_account_id"], name: "index_transactions_on_chart_of_account_id"
    t.index ["date"], name: "index_transactions_on_date"
    t.index ["plaid_transaction_id"], name: "index_transactions_on_plaid_transaction_id", unique: true
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
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "accounts", "companies"
  add_foreign_key "chart_of_accounts", "companies"
  add_foreign_key "company_users", "companies"
  add_foreign_key "company_users", "users"
  add_foreign_key "transactions", "accounts"
  add_foreign_key "transactions", "chart_of_accounts"
end
