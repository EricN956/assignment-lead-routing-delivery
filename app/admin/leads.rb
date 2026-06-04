ActiveAdmin.register Lead do
  menu priority: 2, label: "Leads"

  actions :index, :show

  config.clear_action_items!
  config.sort_order = "created_at_desc"
  config.filters = true
  config.batch_actions = false
  config.per_page = 10

  scope :all, default: true
  Lead::STAGES.each do |stage_name|
    scope(stage_name.humanize) { |scope| scope.where(stage: stage_name) }
  end

  filter :source_claim_id_cont, label: "Source Claim ID"
  filter :publisher_cont, label: "Publisher"
  filter :first_name_or_last_name_cont, label: "Name"
  filter :phone_cont, label: "Phone"
  filter :email_cont, label: "Email"
  filter :stage, as: :select, collection: Lead::STAGES.map { |stage| [stage.humanize, stage] }
  filter :accident_state
  filter :test_lead
  filter :created_at

  index title: "CRM Leads" do
    column "ID", :id
    column "Source Claim", :source_claim_id
    column "Lead", sortable: :last_name do |lead|
      link_to(lead.full_name.presence || "Missing name", admin_lead_path(lead))
    end
    column :publisher
    column :accident_state
    column "Stage" do |lead|
      status_tag(lead.stage)
    end
    column "Type" do |lead|
      lead.test_lead? ? status_tag("test") : "Live"
    end
    column "Deliveries" do |lead|
      lead.lead_deliveries.count
    end
    column "Delivery Status" do |lead|
      summaries = lead.lead_deliveries.includes(:recipient).map do |delivery|
        "#{delivery.recipient&.code || "unknown"}: #{delivery.status}"
      end

      summaries.any? ? summaries.join(", ") : "—"
    end
    column "Conversions" do |lead|
      lead.conversions.count
    end
    column :created_at

    column "" do |lead|
      content_tag :div, class: "aa-actions-group" do
        aa_view_button(admin_lead_path(lead))
      end
    end
  end

  show title: proc { |lead| "Lead #{lead.source_claim_id}" } do
    panel "Lead Summary" do
      attributes_table_for resource do
        row :id
        row :source_claim_id
        row :publisher
        row :stage do |lead|
          status_tag(lead.stage)
        end
        row :test_lead
        row :received_at
        row :created_at
        row :updated_at
      end
    end

    panel "Contact and Incident" do
      attributes_table_for resource do
        row "Name" do |lead|
          lead.full_name.presence || "—"
        end
        row :first_name
        row :last_name
        row :phone
        row :email
        row :address_1
        row :city
        row :state
        row :postal_code
        row :accident_state
        row :incident_date
        row :role
        row :injuries
        row :lead_type
        row :trustedform_cert_url
      end
    end

    panel "Validation and Qualification" do
      attributes_table_for resource do
        row :invalid_reason
        row "Validation errors" do |lead|
          lead.validation_errors.present? ? pre(JSON.pretty_generate(lead.validation_errors)) : "—"
        end
        row "Disqualification reasons" do |lead|
          lead.disqualification_reasons.present? ? pre(JSON.pretty_generate(lead.disqualification_reasons)) : "—"
        end
        row "Prequal" do |lead|
          lead.prequal.present? ? pre(JSON.pretty_generate(lead.prequal)) : "—"
        end
      end
    end

    panel "Recipient Deliveries" do
      table_for resource.lead_deliveries.includes(:recipient).order(created_at: :asc, id: :asc) do
        column :id
        column "Recipient" do |delivery|
          delivery.recipient.code
        end
        column :status do |delivery|
          status_tag(delivery.status)
        end
        column :external_id
        column :attempt_count
        column :next_retry_at
        column :delivered_at
        column :last_error_code
        column :last_error_message
        column :metadata do |delivery|
          delivery.metadata.present? ? pre(JSON.pretty_generate(delivery.metadata)) : "—"
        end
      end
    end

    panel "Dispatch Attempts" do
      table_for resource.dispatch_attempts.includes(lead_delivery: :recipient).order(created_at: :asc, id: :asc) do
        column :id
        column "Recipient" do |attempt|
          attempt.lead_delivery.recipient.code
        end
        column :attempt_number
        column :request_method
        column :request_url
        column :response_status
        column :retryable
        column :error_class
        column :error_message
        column "Request Body" do |attempt|
          attempt.request_body.present? ? pre(JSON.pretty_generate(attempt.request_body)) : "—"
        end
        column "Response Body" do |attempt|
          attempt.response_body.present? ? pre(JSON.pretty_generate(attempt.response_body)) : "—"
        end
        column :created_at
      end
    end

    panel "Conversions and Postbacks" do
      table_for resource.conversions.includes(:recipient).order(created_at: :asc, id: :asc) do
        column :id
        column "Recipient" do |conversion|
          conversion.recipient.code
        end
        column :external_id
        column :disposition do |conversion|
          status_tag(conversion.disposition)
        end
        column :occurred_at
        column :signature do |conversion|
          conversion.signature.present? ? "[FILTERED]" : "—"
        end
        column "Raw Payload" do |conversion|
          conversion.raw_payload.present? ? pre(JSON.pretty_generate(conversion.raw_payload)) : "—"
        end
        column :created_at
      end
    end

    panel "Lifecycle Timeline" do
      table_for resource.stage_events.order(created_at: :asc, id: :asc) do
        column :created_at
        column :from_stage do |event|
          event.from_stage.presence || "—"
        end
        column :to_stage
        column :reason
        column :metadata do |event|
          event.metadata.present? ? pre(JSON.pretty_generate(event.metadata)) : "—"
        end
      end
    end

    panel "Raw Payload" do
      if resource.raw_payload.present?
        pre JSON.pretty_generate(resource.raw_payload)
      else
        "—"
      end
    end
  end

  controller do
    def scoped_collection
      super.includes(lead_deliveries: :recipient)
    end
  end
end
