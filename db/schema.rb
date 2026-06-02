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

ActiveRecord::Schema[8.1].define(version: 2026_06_02_025603) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_admin_comments", force: :cascade do |t|
    t.bigint "author_id"
    t.string "author_type"
    t.text "body"
    t.datetime "created_at", null: false
    t.string "namespace"
    t.bigint "resource_id"
    t.string "resource_type"
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource"
  end

  create_table "admin_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "conversions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "disposition", null: false
    t.string "external_id"
    t.string "idempotency_key", null: false
    t.bigint "lead_id", null: false
    t.datetime "occurred_at"
    t.jsonb "raw_payload", default: {}, null: false
    t.bigint "recipient_id", null: false
    t.string "signature"
    t.string "source_claim_id", null: false
    t.datetime "updated_at", null: false
    t.index ["disposition"], name: "index_conversions_on_disposition"
    t.index ["external_id"], name: "index_conversions_on_external_id"
    t.index ["idempotency_key"], name: "index_conversions_on_idempotency_key", unique: true
    t.index ["lead_id", "recipient_id"], name: "index_conversions_on_lead_id_and_recipient_id"
    t.index ["lead_id"], name: "index_conversions_on_lead_id"
    t.index ["recipient_id"], name: "index_conversions_on_recipient_id"
    t.index ["source_claim_id"], name: "index_conversions_on_source_claim_id"
    t.check_constraint "disposition::text = ANY (ARRAY['signed'::character varying, 'rejected'::character varying, 'not_qualified'::character varying, 'duplicate'::character varying, 'unknown'::character varying]::text[])", name: "conversions_disposition_check"
  end

  create_table "dispatch_attempts", force: :cascade do |t|
    t.integer "attempt_number", null: false
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.string "error_class"
    t.text "error_message"
    t.bigint "lead_delivery_id", null: false
    t.jsonb "request_body", default: {}, null: false
    t.jsonb "request_headers", default: {}, null: false
    t.string "request_method", null: false
    t.string "request_url", null: false
    t.jsonb "response_body", default: {}, null: false
    t.jsonb "response_headers", default: {}, null: false
    t.integer "response_status"
    t.boolean "retryable", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_dispatch_attempts_on_created_at"
    t.index ["lead_delivery_id", "attempt_number"], name: "index_dispatch_attempts_on_lead_delivery_id_and_attempt_number", unique: true
    t.index ["lead_delivery_id"], name: "index_dispatch_attempts_on_lead_delivery_id"
    t.index ["response_status"], name: "index_dispatch_attempts_on_response_status"
    t.index ["retryable"], name: "index_dispatch_attempts_on_retryable"
  end

  create_table "lead_deliveries", force: :cascade do |t|
    t.integer "attempt_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.string "external_id"
    t.string "last_error_code"
    t.text "last_error_message"
    t.bigint "lead_id", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "next_retry_at"
    t.bigint "recipient_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_lead_deliveries_on_external_id"
    t.index ["lead_id", "recipient_id"], name: "index_lead_deliveries_on_lead_id_and_recipient_id", unique: true
    t.index ["lead_id"], name: "index_lead_deliveries_on_lead_id"
    t.index ["next_retry_at"], name: "index_lead_deliveries_on_next_retry_at"
    t.index ["recipient_id"], name: "index_lead_deliveries_on_recipient_id"
    t.index ["status"], name: "index_lead_deliveries_on_status"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'retrying'::character varying, 'delivered'::character varying, 'duplicate_accepted'::character varying, 'failed'::character varying, 'skipped'::character varying]::text[])", name: "lead_deliveries_status_check"
  end

  create_table "lead_stage_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "from_stage"
    t.bigint "lead_id", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "reason"
    t.string "to_stage", null: false
    t.datetime "updated_at", null: false
    t.index ["lead_id", "created_at"], name: "index_lead_stage_events_on_lead_id_and_created_at"
    t.index ["lead_id"], name: "index_lead_stage_events_on_lead_id"
    t.index ["to_stage"], name: "index_lead_stage_events_on_to_stage"
  end

  create_table "leads", force: :cascade do |t|
    t.string "accident_state"
    t.string "address_1"
    t.string "city"
    t.datetime "created_at", null: false
    t.jsonb "disqualification_reasons", default: [], null: false
    t.string "email"
    t.string "first_name"
    t.date "incident_date"
    t.string "injuries"
    t.string "invalid_reason"
    t.string "last_name"
    t.string "lead_type"
    t.string "phone"
    t.string "postal_code"
    t.jsonb "prequal", default: {}, null: false
    t.string "publisher", null: false
    t.jsonb "raw_payload", default: {}, null: false
    t.datetime "received_at"
    t.string "role"
    t.string "source_claim_id", null: false
    t.string "stage", default: "received", null: false
    t.string "state"
    t.boolean "test_lead", default: false, null: false
    t.string "trustedform_cert_url"
    t.datetime "updated_at", null: false
    t.jsonb "validation_errors", default: {}, null: false
    t.index ["accident_state"], name: "index_leads_on_accident_state"
    t.index ["email"], name: "index_leads_on_email"
    t.index ["phone"], name: "index_leads_on_phone"
    t.index ["publisher"], name: "index_leads_on_publisher"
    t.index ["source_claim_id"], name: "index_leads_on_source_claim_id", unique: true
    t.index ["stage"], name: "index_leads_on_stage"
    t.index ["test_lead"], name: "index_leads_on_test_lead"
    t.check_constraint "stage::text = ANY (ARRAY['received'::character varying, 'invalid'::character varying, 'validated'::character varying, 'suppressed'::character varying, 'scrubbed'::character varying, 'disqualified'::character varying, 'qualified'::character varying, 'test'::character varying, 'unroutable'::character varying, 'routed'::character varying, 'dispatched'::character varying, 'delivered'::character varying, 'failed'::character varying, 'converted'::character varying, 'rejected'::character varying]::text[])", name: "leads_stage_check"
  end

  create_table "recipients", force: :cascade do |t|
    t.string "accepted_states", default: [], null: false, array: true
    t.boolean "active", default: true, null: false
    t.string "auth_type", default: "none", null: false
    t.string "base_url", null: false
    t.string "client_class", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.integer "daily_cap"
    t.string "endpoint_path", null: false
    t.string "name", null: false
    t.integer "priority", default: 100, null: false
    t.jsonb "settings", default: {}, null: false
    t.string "transport", default: "http", null: false
    t.datetime "updated_at", null: false
    t.index ["accepted_states"], name: "index_recipients_on_accepted_states", using: :gin
    t.index ["active"], name: "index_recipients_on_active"
    t.index ["code"], name: "index_recipients_on_code", unique: true
    t.index ["priority"], name: "index_recipients_on_priority"
    t.check_constraint "auth_type::text = ANY (ARRAY['none'::character varying, 'api_key'::character varying, 'bearer_token'::character varying, 'custom'::character varying]::text[])", name: "recipients_auth_type_check"
    t.check_constraint "transport::text = 'http'::text", name: "recipients_transport_check"
  end

  add_foreign_key "conversions", "leads"
  add_foreign_key "conversions", "recipients"
  add_foreign_key "dispatch_attempts", "lead_deliveries"
  add_foreign_key "lead_deliveries", "leads"
  add_foreign_key "lead_deliveries", "recipients"
  add_foreign_key "lead_stage_events", "leads"
end
