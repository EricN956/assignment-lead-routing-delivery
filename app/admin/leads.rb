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

  controller do
    def scoped_collection
      super.includes(lead_deliveries: :recipient)
    end
  end
end
