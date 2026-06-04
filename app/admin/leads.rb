ActiveAdmin.register Lead do
  menu priority: 2, label: "Leads"

  actions :index, :show

  config.sort_order = "created_at_desc"

  scope :all, default: true
  Lead::STAGES.each do |stage_name|
    scope(stage_name.humanize) { |scope| scope.where(stage: stage_name) }
  end

  filter :source_claim_id_cont, label: "Source Claim ID"
  filter :publisher_cont, label: "Publisher"
  filter :first_name_or_last_name_cont, label: "Name"
  filter :phone_cont, label: "Phone"
  filter :email_cont, label: "Email"
  filter :stage,
         as: :select,
         collection: Lead::STAGES.map { |stage| [stage.humanize, stage] }
  filter :accident_state
  filter :test_lead
  filter :created_at

  index title: "CRM Leads" do
    selectable_column
    id_column

    column :source_claim_id
    column "Name", sortable: :last_name do |lead|
      lead.full_name.presence || status_tag("Missing", class: "warning")
    end
    column :publisher
    column :phone
    column :email
    column :accident_state
    column :stage do |lead|
      status_tag(lead.stage)
    end
    column :test_lead
    column "Deliveries" do |lead|
      if lead.lead_deliveries.loaded? || lead.lead_deliveries.exists?
        lead.lead_deliveries.includes(:recipient).map do |delivery|
          "#{delivery.recipient.code}: #{delivery.status}"
        end.join(", ")
      else
        "—"
      end
    end
    column :created_at
    actions defaults: true
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
