require "rails_helper"

RSpec.describe Leads::DncScrubber do
  FakeResult = Data.define(:phone, :blocked, :status, :response_body) do
    def blocked?
      blocked == true
    end
  end

  class FakeDncClient
    def initialize(result)
      @result = result
    end

    def call(_phone)
      @result
    end
  end

  def build_lead(phone:, stage: "validated")
    Lead.create!(
      source_claim_id: "RAV-DNC-#{SecureRandom.hex(4)}",
      publisher: "publisher_alpha",
      first_name: "Dnc",
      last_name: "Check",
      phone: phone,
      email: "dnc@example.com",
      accident_state: "TX",
      incident_date: Date.current,
      lead_type: "accident_case",
      stage: stage
    )
  end

  it "moves blocked validated leads to suppressed" do
    lead = build_lead(phone: "5550000001")
    result = FakeResult.new(
      phone: "5550000001",
      blocked: true,
      status: 200,
      response_body: { "phone" => "5550000001", "blocked" => true }
    )

    described_class.new(lead, client: FakeDncClient.new(result)).call

    expect(lead.reload.stage).to eq("suppressed")
    expect(lead.latest_stage_event).to have_attributes(
      from_stage: "validated",
      to_stage: "suppressed",
      reason: "dnc_blocked"
    )
    expect(lead.latest_stage_event.metadata).to include(
      "blocked" => true,
      "phone" => "5550000001",
      "provider" => "mock_dnc"
    )
  end

  it "moves clear validated leads to scrubbed" do
    lead = build_lead(phone: "5553386115")
    result = FakeResult.new(
      phone: "5553386115",
      blocked: false,
      status: 200,
      response_body: { "phone" => "5553386115", "blocked" => false }
    )

    described_class.new(lead, client: FakeDncClient.new(result)).call

    expect(lead.reload.stage).to eq("scrubbed")
    expect(lead.latest_stage_event).to have_attributes(
      from_stage: "validated",
      to_stage: "scrubbed",
      reason: "dnc_clear"
    )
  end

  it "does not rescrub leads outside validated stage" do
    lead = build_lead(phone: "5553386115", stage: "invalid")

    described_class.new(lead, client: double("unused")).call

    expect(lead.reload.stage).to eq("invalid")
  end
end
