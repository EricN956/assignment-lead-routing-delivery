require "rails_helper"

RSpec.describe LeadDelivery, type: :model do
  let(:lead) do
    Lead.create!(
      source_claim_id: "RAV-DELIVERY-1",
      publisher: "publisher_alpha"
    )
  end

  let(:recipient) do
    Recipient.create!(
      code: "apex",
      name: "Apex Legal Intake",
      accepted_states: %w[TX FL],
      base_url: "http://localhost:3100",
      endpoint_path: "/apex/v2/leads",
      auth_type: "api_key",
      client_class: "Recipients::ApexClient"
    )
  end

  subject(:delivery) do
    described_class.new(lead: lead, recipient: recipient)
  end

  it "is valid for one lead and one recipient" do
    expect(delivery).to be_valid
  end

  it "prevents duplicate delivery records for the same lead and recipient" do
    described_class.create!(lead: lead, recipient: recipient)

    duplicate = described_class.new(lead: lead, recipient: recipient)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:lead_id]).to be_present
  end

  it "knows successful terminal statuses" do
    delivery.status = "delivered"

    expect(delivery.successful?).to be(true)
    expect(delivery.final?).to be(true)
  end
  it "knows failed and skipped are final but not successful" do
    delivery.status = "failed"

    expect(delivery).not_to be_successful
    expect(delivery).to be_final

    delivery.status = "skipped"

    expect(delivery).not_to be_successful
    expect(delivery).to be_final
  end
end
