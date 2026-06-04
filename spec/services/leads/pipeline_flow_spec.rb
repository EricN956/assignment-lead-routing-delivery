require "rails_helper"

RSpec.describe "Lead DNC, qualification, and routing pipeline" do
  FakeDncResult = Data.define(:phone, :blocked, :status, :response_body) do
    def blocked?
      blocked == true
    end
  end

  class PipelineFakeDncClient
    def initialize(blocked_phones)
      @blocked_phones = blocked_phones
    end

    def call(phone)
      normalized_phone = Leads::PhoneNormalizer.call(phone)
      blocked = @blocked_phones.include?(normalized_phone)

      FakeDncResult.new(
        normalized_phone,
        blocked,
        200,
        {
          "phone" => normalized_phone,
          "blocked" => blocked
        }
      )
    end
  end

  def sample_rows
    JSON.parse(File.read(Rails.root.join("data/inbound_leads.json")))
  end

  def sample_ids
    sample_rows.map { |row| row["source_claim_id"] }.compact.uniq
  end

  def blocked_dnc_phones
    sample_rows
      .select { |row| %w[RAV-1013 RAV-1014].include?(row["source_claim_id"]) }
      .map { |row| Leads::PhoneNormalizer.call(row["phone"]) }
      .compact
  end

  def import_sample
    Leads::JsonImporter.call(Rails.root.join("data/inbound_leads.json"))
  end

  def run_dnc_scrub
    fake_client = PipelineFakeDncClient.new(blocked_dnc_phones)

    Lead.where(stage: "validated").find_each do |lead|
      Leads::DncScrubber.new(lead, client: fake_client).call
    end
  end

  def run_qualification
    Lead.where(stage: "scrubbed").find_each do |lead|
      Leads::QualificationProcessor.call(lead)
    end
  end

  def run_routing
    Rails.application.load_seed

    Lead.where(stage: "qualified").find_each do |lead|
      Leads::RoutingProcessor.call(lead)
    end
  end

  it "moves validated sample leads through DNC with deterministic suppressed counts" do
    import_sample
    run_dnc_scrub

    expect(Lead.where(source_claim_id: sample_ids, stage: "validated").count).to eq(0)
    expect(Lead.where(source_claim_id: sample_ids, stage: "scrubbed").count).to eq(18)
    expect(Lead.where(source_claim_id: sample_ids, stage: "suppressed").count).to eq(2)
    expect(Lead.where(source_claim_id: sample_ids, stage: "invalid").count).to eq(4)

    expect(Lead.where(source_claim_id: %w[RAV-1013 RAV-1014]).pluck(:stage)).to contain_exactly(
      "suppressed",
      "suppressed"
    )

    suppressed = Lead.find_by!(source_claim_id: "RAV-1013")
    expect(suppressed.latest_stage_event).to have_attributes(
      from_stage: "validated",
      to_stage: "suppressed",
      reason: "dnc_blocked"
    )
    expect(suppressed.latest_stage_event.metadata).to include(
      "provider" => "mock_dnc",
      "blocked" => true
    )
  end

  it "qualifies scrubbed sample leads with deterministic pass and fail counts" do
    import_sample
    run_dnc_scrub
    run_qualification

    expect(Lead.where(source_claim_id: sample_ids, stage: "qualified").count).to eq(14)
    expect(Lead.where(source_claim_id: sample_ids, stage: "disqualified").count).to eq(3)
    expect(Lead.where(source_claim_id: sample_ids, stage: "test").count).to eq(1)
    expect(Lead.where(source_claim_id: sample_ids, stage: "suppressed").count).to eq(2)
    expect(Lead.where(source_claim_id: sample_ids, stage: "invalid").count).to eq(4)

    expect(Lead.find_by!(source_claim_id: "RAV-1020").disqualification_reasons.map { |reason| reason["code"] }).to eq(["within_1_year"])
    expect(Lead.find_by!(source_claim_id: "RAV-1021").disqualification_reasons.map { |reason| reason["code"] }).to eq(["not_at_fault"])
    expect(Lead.find_by!(source_claim_id: "RAV-1022").disqualification_reasons.map { |reason| reason["code"] }).to eq(["has_no_attorney"])

    test_lead = Lead.find_by!(source_claim_id: "RAV-1023")
    expect(test_lead.stage).to eq("test")
    expect(test_lead.latest_stage_event.reason).to eq("test_lead_skipped")
  end

  it "routes qualified sample leads with deterministic recipient delivery counts" do
    import_sample
    run_dnc_scrub
    run_qualification
    run_routing

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

    routed_sample_leads = Lead
      .where(source_claim_id: sample_ids, stage: "routed")
      .includes(lead_deliveries: :recipient)

    apex_beacon_lead = routed_sample_leads.find do |lead|
      lead.lead_deliveries.map { |delivery| delivery.recipient.code }.sort == %w[apex beacon]
    end

    expect(apex_beacon_lead).to be_present
    expect(apex_beacon_lead.lead_deliveries.map { |delivery| delivery.recipient.code }).to contain_exactly(
      "apex",
      "beacon"
    )

    ny_lead = Lead.find_by!(source_claim_id: "RAV-1001")
    expect(ny_lead.lead_deliveries.includes(:recipient).map { |delivery| delivery.recipient.code }).to contain_exactly(
      "beacon",
      "citadel"
    )
  end

  it "does not route invalid, suppressed, disqualified, test, or unroutable leads" do
    import_sample
    run_dnc_scrub
    run_qualification
    run_routing

    blocked_or_terminal_ids = %w[
      RAV-1013
      RAV-1014
      RAV-1015
      RAV-1016
      RAV-1017
      RAV-BROKEN-1
      RAV-1020
      RAV-1021
      RAV-1022
      RAV-1023
      RAV-1019
    ]

    expect(
      LeadDelivery
        .joins(:lead)
        .where(leads: { source_claim_id: blocked_or_terminal_ids })
        .count
    ).to eq(0)
  end

  it "records lifecycle events for DNC, qualification, and routing decisions" do
    import_sample
    run_dnc_scrub
    run_qualification
    run_routing

    routed = Lead.find_by!(source_claim_id: "RAV-1002")
    disqualified = Lead.find_by!(source_claim_id: "RAV-1021")
    unroutable = Lead.find_by!(source_claim_id: "RAV-1019")

    expect(routed.stage_events.pluck(:reason)).to include(
      "dnc_clear",
      "qualification_passed",
      "routing_completed"
    )
    expect(routed.latest_stage_event).to have_attributes(
      to_stage: "routed",
      reason: "routing_completed"
    )

    expect(disqualified.latest_stage_event).to have_attributes(
      to_stage: "disqualified",
      reason: "qualification_failed"
    )
    expect(disqualified.latest_stage_event.metadata.fetch("failed_rules").first).to include(
      "code" => "not_at_fault"
    )

    expect(unroutable.latest_stage_event).to have_attributes(
      to_stage: "unroutable",
      reason: "no_active_recipient_accepts_state"
    )
  end
end
