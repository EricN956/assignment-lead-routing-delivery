class CreateLeadsAndLeadStageEvents < ActiveRecord::Migration[8.1]
  LEAD_STAGES = %w[
    received
    invalid
    validated
    suppressed
    scrubbed
    disqualified
    qualified
    test
    unroutable
    routed
    dispatched
    delivered
    failed
    converted
    rejected
  ].freeze

  def change
    create_table :leads do |t|
      t.string :source_claim_id, null: false
      t.string :publisher, null: false
      t.datetime :received_at

      t.string :stage, null: false, default: "received"

      t.string :first_name
      t.string :last_name
      t.string :phone
      t.string :email

      t.string :address_1
      t.string :city
      t.string :state
      t.string :postal_code

      t.string :accident_state
      t.date :incident_date
      t.string :role
      t.string :injuries
      t.string :lead_type
      t.boolean :test_lead, null: false, default: false
      t.string :trustedform_cert_url

      t.jsonb :prequal, null: false, default: {}
      t.jsonb :raw_payload, null: false, default: {}
      t.jsonb :validation_errors, null: false, default: {}
      t.jsonb :disqualification_reasons, null: false, default: []

      t.string :invalid_reason

      t.timestamps
    end

    add_index :leads, :source_claim_id, unique: true
    add_index :leads, :publisher
    add_index :leads, :stage
    add_index :leads, :accident_state
    add_index :leads, :phone
    add_index :leads, :email
    add_index :leads, :test_lead

    add_check_constraint(
      :leads,
      "stage IN (#{LEAD_STAGES.map { |stage| "'#{stage}'" }.join(', ')})",
      name: "leads_stage_check"
    )

    create_table :lead_stage_events do |t|
      t.references :lead, null: false, foreign_key: true
      t.string :from_stage
      t.string :to_stage, null: false
      t.string :reason
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :lead_stage_events, [:lead_id, :created_at]
    add_index :lead_stage_events, :to_stage
  end
end
