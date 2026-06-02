class CreateRecipientDeliveryDomain < ActiveRecord::Migration[8.1]
  RECIPIENT_TRANSPORTS = %w[http].freeze
  RECIPIENT_AUTH_TYPES = %w[none api_key bearer_token custom].freeze

  DELIVERY_STATUSES = %w[
    pending
    retrying
    delivered
    duplicate_accepted
    failed
    skipped
  ].freeze

  CONVERSION_DISPOSITIONS = %w[
    signed
    rejected
    not_qualified
    duplicate
    unknown
  ].freeze

  def change
    create_table :recipients do |t|
      t.string :code, null: false
      t.string :name, null: false

      t.boolean :active, null: false, default: true
      t.integer :priority, null: false, default: 100
      t.integer :daily_cap

      t.string :accepted_states, array: true, null: false, default: []

      t.string :transport, null: false, default: "http"
      t.string :base_url, null: false
      t.string :endpoint_path, null: false
      t.string :auth_type, null: false, default: "none"
      t.string :client_class, null: false

      t.jsonb :settings, null: false, default: {}

      t.timestamps
    end

    add_index :recipients, :code, unique: true
    add_index :recipients, :active
    add_index :recipients, :priority
    add_index :recipients, :accepted_states, using: :gin

    add_check_constraint(
      :recipients,
      "transport IN (#{RECIPIENT_TRANSPORTS.map { |value| "'#{value}'" }.join(', ')})",
      name: "recipients_transport_check"
    )

    add_check_constraint(
      :recipients,
      "auth_type IN (#{RECIPIENT_AUTH_TYPES.map { |value| "'#{value}'" }.join(', ')})",
      name: "recipients_auth_type_check"
    )

    create_table :lead_deliveries do |t|
      t.references :lead, null: false, foreign_key: true
      t.references :recipient, null: false, foreign_key: true

      t.string :status, null: false, default: "pending"
      t.string :external_id

      t.integer :attempt_count, null: false, default: 0
      t.datetime :next_retry_at
      t.datetime :delivered_at

      t.string :last_error_code
      t.text :last_error_message

      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :lead_deliveries, [:lead_id, :recipient_id], unique: true
    add_index :lead_deliveries, :status
    add_index :lead_deliveries, :external_id
    add_index :lead_deliveries, :next_retry_at

    add_check_constraint(
      :lead_deliveries,
      "status IN (#{DELIVERY_STATUSES.map { |value| "'#{value}'" }.join(', ')})",
      name: "lead_deliveries_status_check"
    )

    create_table :dispatch_attempts do |t|
      t.references :lead_delivery, null: false, foreign_key: true

      t.integer :attempt_number, null: false
      t.string :request_method, null: false
      t.string :request_url, null: false

      t.jsonb :request_headers, null: false, default: {}
      t.jsonb :request_body, null: false, default: {}

      t.integer :response_status
      t.jsonb :response_headers, null: false, default: {}
      t.jsonb :response_body, null: false, default: {}

      t.integer :duration_ms
      t.string :error_class
      t.text :error_message
      t.boolean :retryable, null: false, default: false

      t.timestamps
    end

    add_index :dispatch_attempts, [:lead_delivery_id, :attempt_number], unique: true
    add_index :dispatch_attempts, :response_status
    add_index :dispatch_attempts, :retryable
    add_index :dispatch_attempts, :created_at

    create_table :conversions do |t|
      t.references :lead, null: false, foreign_key: true
      t.references :recipient, null: false, foreign_key: true

      t.string :source_claim_id, null: false
      t.string :external_id
      t.string :disposition, null: false
      t.datetime :occurred_at
      t.string :signature
      t.string :idempotency_key, null: false

      t.jsonb :raw_payload, null: false, default: {}

      t.timestamps
    end

    add_index :conversions, :idempotency_key, unique: true
    add_index :conversions, :source_claim_id
    add_index :conversions, :external_id
    add_index :conversions, :disposition
    add_index :conversions, [:lead_id, :recipient_id]

    add_check_constraint(
      :conversions,
      "disposition IN (#{CONVERSION_DISPOSITIONS.map { |value| "'#{value}'" }.join(', ')})",
      name: "conversions_disposition_check"
    )
  end
end
