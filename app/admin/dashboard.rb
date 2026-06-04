ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: "Dashboard"

  content title: "Lead Routing CRM Dashboard" do
    panel "Lead Lifecycle Summary" do
      stage_rows = Lead::STAGES.map do |stage|
        {
          stage: stage,
          count: Lead.where(stage: stage).count
        }
      end

      table_for stage_rows do
        column "Stage" do |row|
          status_tag(row.fetch(:stage))
        end
        column "Count" do |row|
          row.fetch(:count)
        end
      end
    end

    panel "Delivery Status Summary" do
      delivery_rows = LeadDelivery::STATUSES.map do |status|
        {
          status: status,
          count: LeadDelivery.where(status: status).count
        }
      end

      table_for delivery_rows do
        column "Status" do |row|
          status_tag(row.fetch(:status))
        end
        column "Count" do |row|
          row.fetch(:count)
        end
      end
    end

    panel "Recent Failed Dispatch Attempts" do
      attempts = DispatchAttempt
        .where("error_class IS NOT NULL OR response_status >= ?", 400)
        .includes(lead_delivery: [:lead, :recipient])
        .order(created_at: :desc)
        .limit(10)

      if attempts.any?
        table_for attempts do
          column :created_at
          column "Lead" do |attempt|
            attempt.lead_delivery.lead.source_claim_id
          end
          column "Recipient" do |attempt|
            attempt.lead_delivery.recipient.code
          end
          column :attempt_number
          column :response_status
          column "Delivery Error Code" do |attempt|
            attempt.lead_delivery.last_error_code.presence || "—"
          end
          column :error_class
          column :error_message
          column :retryable
        end
      else
        div "No failed dispatch attempts recorded."
      end
    end

    panel "Recent Conversions and Postbacks" do
      conversions = Conversion
        .includes(:lead, :recipient)
        .order(created_at: :desc)
        .limit(10)

      if conversions.any?
        table_for conversions do
          column :created_at
          column "Lead" do |conversion|
            conversion.lead.source_claim_id
          end
          column "Recipient" do |conversion|
            conversion.recipient.code
          end
          column :external_id
          column :disposition do |conversion|
            status_tag(conversion.disposition)
          end
          column :occurred_at
        end
      else
        div "No conversions recorded."
      end
    end

    panel "Recent Leads" do
      leads = Lead.order(created_at: :desc).limit(10)

      if leads.any?
        table_for leads do
          column :created_at
          column :source_claim_id
          column :publisher
          column :accident_state
          column :stage do |lead|
            status_tag(lead.stage)
          end
          column "Deliveries" do |lead|
            lead.lead_deliveries.count
          end
          column "Conversions" do |lead|
            lead.conversions.count
          end
        end
      else
        div "No leads imported yet."
      end
    end
  end
end
