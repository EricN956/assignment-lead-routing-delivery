require "rails_helper"

RSpec.describe Conversion, type: :model do
  let(:lead) do
    Lead.create!(
      source_claim_id: "RAV-CONVERSION-1",
      publisher: "publisher_alpha"
    )
  end

  let(:recipient) do
    Recipient.create!(
      code: "citadel",
      name: "Citadel Case Desk",
      accepted_states: %w[FL GA],
      base_url: "http://localhost:3100",
      endpoint_path: "/citadel/intake",
      auth_type: "bearer_token",
      client_class: "Recipients::CitadelClient"
    )
  end

  subject(:conversion) do
    described_class.new(
      lead: lead,
      recipient: recipient,
      source_claim_id: lead.source_claim_id,
      external_id: "CIT-123",
      disposition: "signed",
      idempotency_key: "citadel:RAV-CONVERSION-1:CIT-123:signed",
      raw_payload: { "disposition" => "signed" }
    )
  end

  it "is valid with postback identity fields" do
    expect(conversion).to be_valid
  end

  it "requires an idempotency key" do
    conversion.idempotency_key = nil

    expect(conversion).not_to be_valid
    expect(conversion.errors[:idempotency_key]).to be_present
  end

  it "prevents duplicate postback records" do
    conversion.save!

    duplicate = conversion.dup

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:idempotency_key]).to be_present
  end
end
