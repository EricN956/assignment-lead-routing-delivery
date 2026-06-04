ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: "Dashboard"

  content title: "Lead Routing CRM Dashboard" do
    total_leads = Lead.count
    validated_leads = Lead.where(stage: "validated").count
    invalid_leads = Lead.where(stage: "invalid").count
    routed_leads = Lead.where(stage: "routed").count
    delivered_leads = Lead.where(stage: "delivered").count
    converted_leads = Lead.where(stage: "converted").count
stage_colors = {
  "received" => "#94A3B8",
  "invalid" => "#B42318",
  "validated" => "#0F766E",
  "suppressed" => "#B7791F",
  "scrubbed" => "#64748B",
  "disqualified" => "#C2410C",
  "qualified" => "#4F46E5",
  "test" => "#7C3AED",
  "unroutable" => "#92400E",
  "routed" => "#1D4ED8",
  "dispatched" => "#0284C7",
  "delivered" => "#047857",
  "failed" => "#BE123C",
  "converted" => "#155E75",
  "rejected" => "#9F1239"
}

    stage_rows = Lead::STAGES.map do |stage|
      { stage: stage, count: Lead.where(stage: stage).count }
    end

    active_stage_rows = stage_rows.select { |row| row.fetch(:count).to_i.positive? }
    max_stage_count = [active_stage_rows.map { |row| row.fetch(:count).to_i }.max.to_i, 1].max

    cursor = 0.0
    donut_segments = active_stage_rows.map do |row|
      stage = row.fetch(:stage)
      count = row.fetch(:count).to_i
      percent = total_leads.positive? ? (count.to_f / total_leads * 100.0) : 0.0

      start_at = cursor
      end_at = cursor + percent
      cursor = end_at

      color = stage_colors.fetch(stage, "#64748b")
      gap = percent >= 7 ? 0.75 : 0.25
      color_end = [end_at - gap, start_at].max

      "#{color} #{start_at.round(2)}% #{color_end.round(2)}%, #ffffff #{color_end.round(2)}% #{end_at.round(2)}%"
    end

    donut_background =
      if donut_segments.any?
        "conic-gradient(from -90deg, #{donut_segments.join(", ")})"
      else
        "conic-gradient(from -90deg, #e5e7eb 0% 100%)"
      end

    div class: "crm-hero" do
      h3 "Lead Routing Operations"
      para "Operational view of intake quality, routing readiness, delivery health, and conversion activity."
    end

    div class: "crm-stats-grid" do
      [
        ["Total Leads", total_leads],
        ["Validated", validated_leads],
        ["Invalid", invalid_leads],
        ["Routed", routed_leads],
        ["Delivered", delivered_leads],
        ["Converted", converted_leads]
      ].each do |label, value|
        div class: "crm-stat-card" do
          span label
          strong value
        end
      end
    end

    div class: "crm-dashboard-main-grid" do
      panel "Lead Lifecycle Summary" do
        div class: "crm-lifecycle-card" do
          div class: "crm-lifecycle-donut-area" do
            div class: "crm-lifecycle-donut", style: "background: #{donut_background}" do
              div class: "crm-lifecycle-donut-hole" do
                strong total_leads
                span "Total leads"
              end
            end
          end

          div class: "crm-lifecycle-list" do
            if active_stage_rows.any?
              active_stage_rows.each do |row|
                stage = row.fetch(:stage)
                count = row.fetch(:count).to_i
                percent = total_leads.positive? ? ((count.to_f / total_leads) * 100).round : 0
                bar_percent = ((count.to_f / max_stage_count) * 100).round
                color = stage_colors.fetch(stage, "#64748b")

                div class: "crm-lifecycle-row" do
                  div class: "crm-lifecycle-label" do
                    span "", class: "crm-lifecycle-dot", style: "background: #{color}"
                    span stage.humanize
                  end

                  div class: "crm-lifecycle-track" do
                    div class: "crm-lifecycle-fill", style: "width: #{bar_percent}%; background: #{color}"
                  end

                  div "#{count} · #{percent}%", class: "crm-lifecycle-value"
                end
              end
            else
              div "No lead stages recorded yet.", class: "blank_slate"
            end
          end
        end
      end

      panel "Recent Leads" do
        leads = Lead.order(created_at: :desc).limit(8)

        if leads.any?
          table_for leads do
            column :created_at
            column("Source Claim") { |lead| link_to lead.source_claim_id, admin_lead_path(lead) }
            column :publisher
            column :accident_state
            column(:stage) { |lead| status_tag(lead.stage) }
          end
        else
          div "No leads imported yet.", class: "blank_slate"
        end
      end
    end

    div class: "crm-grid-two" do
      panel "Delivery Status Summary" do
        delivery_rows = LeadDelivery::STATUSES.map do |status|
          { status: status, count: LeadDelivery.where(status: status).count }
        end

        table_for delivery_rows do
          column("Status") { |row| status_tag(row.fetch(:status)) }
          column("Count") { |row| row.fetch(:count) }
        end
      end

      panel "Recent Failed Dispatch Attempts" do
        attempts = DispatchAttempt
          .where("error_class IS NOT NULL OR response_status >= ?", 400)
          .includes(lead_delivery: [:lead, :recipient])
          .order(created_at: :desc)
          .limit(6)

        if attempts.any?
          table_for attempts do
            column :created_at
            column("Lead") { |attempt| link_to attempt.lead_delivery.lead.source_claim_id, admin_lead_path(attempt.lead_delivery.lead) }
            column("Recipient") { |attempt| attempt.lead_delivery.recipient.code }
            column :response_status
            column "Delivery Error Code" do |attempt|
              attempt.lead_delivery.last_error_code.presence || "—"
            end
            column "Error" do |attempt|
              attempt.error_message.presence || attempt.lead_delivery.last_error_message.presence || "—"
            end
          end
        else
          div "No failed dispatch attempts recorded.", class: "blank_slate"
        end
      end
    end

    panel "Recent Conversions and Postbacks" do
      conversions = Conversion.includes(:lead, :recipient).order(created_at: :desc).limit(8)

      if conversions.any?
        table_for conversions do
          column :created_at
          column("Lead") { |conversion| link_to conversion.lead.source_claim_id, admin_lead_path(conversion.lead) }
          column("Recipient") { |conversion| conversion.recipient.code }
          column :external_id
          column(:disposition) { |conversion| status_tag(conversion.disposition) }
        end
      else
        div "No conversions recorded.", class: "blank_slate"
      end
    end
  end
end
