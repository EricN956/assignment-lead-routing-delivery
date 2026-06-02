require "rails_helper"

RSpec.describe Leads::PayloadNormalizer do
  let(:payload) do
    {
      "source_claim_id" => " RAV-1001 ",
      "publisher" => "publisher_alpha",
      "received_at" => "2026-05-31T09:00:00Z",
      "first_name" => "Jordan",
      "last_name" => "Carter",
      "phone" => "+1 (555) 314-2271",
      "email" => " USER1001@EXAMPLE.COM ",
      "state" => "tx",
      "accident_state" => "fl",
      "incident_date" => "2026-04-02",
      "lead_type" => "accident_case",
      "test_lead" => false,
      "prequal" => { "has_injuries" => true }
    }
  end

  it "maps publisher payload into Lead attributes" do
    attributes = described_class.call(payload)

    expect(attributes).to include(
      source_claim_id: "RAV-1001",
      publisher: "publisher_alpha",
      phone: "5553142271",
      email: "user1001@example.com",
      state: "TX",
      accident_state: "FL",
      incident_date: Date.iso8601("2026-04-02"),
      lead_type: "accident_case",
      test_lead: false
    )
    expect(attributes[:prequal]).to eq("has_injuries" => true)
    expect(attributes[:raw_payload]["source_claim_id"]).to eq(" RAV-1001 ")
  end

  it "returns nil dates for invalid dates instead of raising" do
    attributes = described_class.call(payload.merge("incident_date" => "not-a-date"))

    expect(attributes[:incident_date]).to be_nil
  end

  it "handles non-hash payloads defensively" do
    attributes = described_class.call(nil)

    expect(attributes[:raw_payload]).to eq({})
  end
end
