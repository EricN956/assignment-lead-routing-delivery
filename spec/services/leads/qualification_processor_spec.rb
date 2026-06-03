require "rails_helper"

RSpec.describe Leads::QualificationProcessor do
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

  def create_scrubbed_lead(overrides = {})
    Lead.create!(
      {
        source_claim_id: "RAV-QUAL-#{SecureRandom.hex(4)}",
        publisher: "publisher_alpha",
        first_name: "Quinn",
        last_name: "Taylor",
        phone: "5553386115",
        email: "qual@example.com",
        accident_state: "TX",
        incident_date: Date.current,
        lead_type: "accident_case",
        stage: "scrubbed",
        prequal: passing_prequal
      }.merge(overrides)
    )
  end

  it "moves passing scrubbed leads to qualified" do
    lead = create_scrubbed_lead

    described_class.call(lead)

    expect(lead.reload.stage).to eq("qualified")
    expect(lead.disqualification_reasons).to eq([])
    expect(lead.latest_stage_event).to have_attributes(
      from_stage: "scrubbed",
      to_stage: "qualified",
      reason: "qualification_passed"
    )
  end

  it "moves failing scrubbed leads to disqualified with rule reasons" do
    lead = create_scrubbed_lead(
      prequal: passing_prequal.merge(
        "not_at_fault" => false,
        "has_no_attorney" => false
      )
    )

    described_class.call(lead)

    expect(lead.reload.stage).to eq("disqualified")
    expect(lead.disqualification_reasons.map { |reason| reason["code"] }).to contain_exactly(
      "not_at_fault",
      "has_no_attorney"
    )
    expect(lead.latest_stage_event.reason).to eq("qualification_failed")
  end

  it "moves test leads to the test stage without evaluating recipient routing" do
    lead = create_scrubbed_lead(test_lead: true)

    described_class.call(lead)

    expect(lead.reload.stage).to eq("test")
    expect(lead.latest_stage_event).to have_attributes(
      from_stage: "scrubbed",
      to_stage: "test",
      reason: "test_lead_skipped"
    )
  end

  it "ignores leads outside scrubbed stage" do
    lead = create_scrubbed_lead(stage: "validated")

    described_class.call(lead)

    expect(lead.reload.stage).to eq("validated")
  end

  it "processes the sample data with expected deterministic qualification counts" do
    Leads::JsonImporter.call(Rails.root.join("data/inbound_leads.json"))

    Lead.where(stage: "validated").find_each do |lead|
      lead.transition_to!("scrubbed", reason: "qualification_spec_setup")
    end

    Lead.where(stage: "scrubbed").find_each do |lead|
      described_class.call(lead)
    end

    sample_ids = JSON.parse(File.read(Rails.root.join("data/inbound_leads.json"))).map { |row| row["source_claim_id"] }.compact.uniq

    expect(Lead.where(source_claim_id: sample_ids, stage: "qualified").count).to eq(16)
    expect(Lead.where(source_claim_id: sample_ids, stage: "disqualified").count).to eq(3)
    expect(Lead.where(source_claim_id: sample_ids, stage: "test").count).to eq(1)

    expect(Lead.find_by!(source_claim_id: "RAV-1020").disqualification_reasons.map { |reason| reason["code"] }).to eq(["within_1_year"])
    expect(Lead.find_by!(source_claim_id: "RAV-1021").disqualification_reasons.map { |reason| reason["code"] }).to eq(["not_at_fault"])
    expect(Lead.find_by!(source_claim_id: "RAV-1022").disqualification_reasons.map { |reason| reason["code"] }).to eq(["has_no_attorney"])
  end
end
