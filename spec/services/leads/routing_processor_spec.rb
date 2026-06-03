require "rails_helper"

RSpec.describe Leads::RoutingProcessor do
  before do
    Rails.application.load_seed
  end

  def passing_prequal
    {
      "has_injuries" => true,
      "not_at_fault" => true,
      "within_1_year" => true,
      "has_no_attorney" => true,
      "not_previously_dropped_or_settled" => true,
      "has_received_medical_treatment" => true
    }
  end

  def create_qualified_lead(overrides = {})
    Lead.create!(
      {
        source_claim_id: "RAV-ROUTE-#{SecureRandom.hex(4)}",
        publisher: "publisher_alpha",
        first_name: "Riley",
        last_name: "Morgan",
        phone: "5553386115",
        email: "route@example.com",
        accident_state: "TX",
        incident_date: Date.current,
        lead_type: "accident_case",
        stage: "qualified",
        prequal: passing_prequal
      }.merge(overrides)
    )
  end

  it "creates delivery records for eligible recipients" do
    lead = create_qualified_lead(accident_state: "TX")

    result = described_class.call(lead)

    expect(result).to be_routed
    expect(result.recipient_codes).to eq(%w[apex beacon])
    expect(result.deliveries.map { |delivery| delivery.recipient.code }).to eq(%w[apex beacon])
    expect(lead.reload.stage).to eq("routed")
    expect(lead.latest_stage_event).to have_attributes(
      from_stage: "qualified",
      to_stage: "routed",
      reason: "routing_completed"
    )
  end

  it "moves leads with no eligible recipients to unroutable" do
    lead = create_qualified_lead(accident_state: "WY")

    result = described_class.call(lead)

    expect(result).to be_unroutable
    expect(result.unroutable_reason).to eq("no_active_recipient_accepts_state")
    expect(result.deliveries).to eq([])
    expect(lead.reload.stage).to eq("unroutable")
  end

  it "does not process leads outside qualified stage" do
    lead = create_qualified_lead(stage: "scrubbed")

    result = described_class.call(lead)

    expect(result).to be_unroutable
    expect(result.unroutable_reason).to eq("lead_not_qualified")
    expect(lead.reload.stage).to eq("scrubbed")
    expect(lead.lead_deliveries).to be_empty
  end

  it "does not create duplicate delivery records if called again after routing" do
    lead = create_qualified_lead(accident_state: "TX")

    described_class.call(lead)
    described_class.call(lead.reload)

    expect(lead.lead_deliveries.count).to eq(2)
  end

  it "routes the sample pipeline with deterministic recipient delivery counts" do
    Leads::JsonImporter.call(Rails.root.join("data/inbound_leads.json"))

    # Simulate the deterministic DNC outcome without calling external HTTP.
    %w[RAV-1013 RAV-1014].each do |claim_id|
      Lead.find_by!(source_claim_id: claim_id).transition_to!(
        "suppressed",
        reason: "routing_spec_dnc_blocked"
      )
    end

    Lead.where(stage: "validated").find_each do |lead|
      lead.transition_to!("scrubbed", reason: "routing_spec_dnc_clear")
      Leads::QualificationProcessor.call(lead)
      described_class.call(lead.reload)
    end

    sample_ids = JSON.parse(File.read(Rails.root.join("data/inbound_leads.json"))).map { |row| row["source_claim_id"] }.compact.uniq

    expect(Lead.where(source_claim_id: sample_ids, stage: "routed").count).to eq(13)
    expect(Lead.where(source_claim_id: sample_ids, stage: "unroutable").pluck(:source_claim_id)).to eq(["RAV-1019"])
    expect(LeadDelivery.joins(:lead).where(leads: { source_claim_id: sample_ids }).count).to eq(22)

    delivery_counts = LeadDelivery
      .joins(:lead, :recipient)
      .where(leads: { source_claim_id: sample_ids })
      .group("recipients.code")
      .count

    expect(delivery_counts).to eq(
      "apex" => 6,
      "beacon" => 9,
      "citadel" => 7
    )
  end
end
