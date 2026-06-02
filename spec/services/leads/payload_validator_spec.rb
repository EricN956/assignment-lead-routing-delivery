require "rails_helper"

RSpec.describe Leads::PayloadValidator do
  def normalized(payload)
    Leads::PayloadNormalizer.call(payload)
  end

  let(:valid_payload) do
    {
      "source_claim_id" => "RAV-1001",
      "publisher" => "publisher_alpha",
      "received_at" => "2026-05-31T09:00:00Z",
      "first_name" => "Jordan",
      "last_name" => "Carter",
      "phone" => "+1 (555) 314-2271",
      "email" => "user1001@example.com",
      "accident_state" => "TX",
      "incident_date" => "2026-04-02",
      "lead_type" => "accident_case",
      "prequal" => { "has_injuries" => true }
    }
  end

  it "returns valid for a complete normalized payload" do
    attributes = normalized(valid_payload)

    result = described_class.call(attributes)

    expect(result).to be_valid
    expect(result.to_h).to eq({})
  end

  it "returns structured errors for missing email" do
    payload = valid_payload.merge("email" => "")
    attributes = normalized(payload)

    result = described_class.call(attributes)

    expect(result).to be_invalid
    expect(result.to_h["email"]).to include("is required")
  end

  it "returns structured errors for malformed phone numbers" do
    payload = valid_payload.merge("phone" => "(555) 123-99")
    attributes = normalized(payload)

    result = described_class.call(attributes)

    expect(result).to be_invalid
    expect(result.to_h["phone"]).to include("must normalize to 10 digits")
  end

  it "returns structured errors for broken partial records" do
    payload = {
      "source_claim_id" => "RAV-BROKEN-1",
      "publisher" => "publisher_alpha",
      "first_name" => "Only",
      "received_at" => "2026-06-01T08:17:13Z"
    }
    attributes = normalized(payload)

    result = described_class.call(attributes)

    expect(result).to be_invalid
    expect(result.to_h.keys).to include(
      "last_name",
      "phone",
      "email",
      "accident_state",
      "incident_date",
      "lead_type",
      "prequal"
    )
  end
end
