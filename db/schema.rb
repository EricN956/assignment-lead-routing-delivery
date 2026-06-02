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

  add_foreign_key "lead_stage_events", "leads"
end
