require "rails_helper"

RSpec.describe DispatchAttempt, type: :model do
  let(:lead) do
    Lead.create!(
      source_claim_id: "RAV-ATTEMPT-1",
      publisher: "publisher_alpha"
    )
  end

  let(:recipient) do
    Recipient.create!(
      code: "beacon",
      name: "Beacon Claims",
      accepted_states: %w[TX CA],
      base_url: "http://localhost:3100",
      endpoint_path: "/beacon/leads",
      auth_type: "api_key",
      client_class: "Recipients::BeaconClient"
    )
  end

  let(:delivery) do
    LeadDelivery.create!(lead: lead, recipient: recipient)
  end

  subject(:attempt) do
    described_class.new(
      lead_delivery: delivery,
      attempt_number: 1,
      request_method: "POST",
      request_url: "http://localhost:3100/beacon/leads",
      request_body: { "source_claim_id" => lead.source_claim_id }
    )
  end

  it "is valid with request audit data" do
    expect(attempt).to be_valid
  end

  it "requires unique attempt numbers per delivery" do
    described_class.create!(
      lead_delivery: delivery,
      attempt_number: 1,
      request_method: "POST",
      request_url: "http://localhost:3100/beacon/leads"
    )

    expect(attempt).not_to be_valid
    expect(attempt.errors[:attempt_number]).to be_present
  end
end
