require "rails_helper"

RSpec.describe Leads::Routing::RecipientSelector do
  before do
    Rails.application.load_seed
  end

  def build_lead(accident_state)
    Lead.new(
      source_claim_id: "RAV-ROUTE-SELECT",
      publisher: "publisher_alpha",
      accident_state: accident_state,
      stage: "qualified"
    )
  end

  it "selects recipients that accept the lead accident state" do
    recipients = described_class.call(build_lead("TX"))

    expect(recipients.map(&:code)).to eq(%w[apex beacon])
  end

  it "orders recipients by routing priority" do
    recipients = described_class.call(build_lead("NY"))

    expect(recipients.map(&:code)).to eq(%w[beacon citadel])
  end

  it "returns no recipients for unsupported states" do
    recipients = described_class.call(build_lead("WY"))

    expect(recipients).to be_empty
  end

  it "excludes inactive recipients" do
    Recipient.find_by!(code: "beacon").update!(active: false)

    recipients = described_class.call(build_lead("TX"))

    expect(recipients.map(&:code)).to eq(%w[apex])
  end

  it "excludes recipients that reached daily cap" do
    beacon = Recipient.find_by!(code: "beacon")
    beacon.update!(daily_cap: 1)

    lead = Lead.create!(
      source_claim_id: "RAV-CAP-ROUTE-1",
      publisher: "publisher_alpha",
      accident_state: "TX"
    )

    LeadDelivery.create!(
      lead: lead,
      recipient: beacon,
      status: "delivered",
      delivered_at: Time.current
    )

    recipients = described_class.call(build_lead("TX"))

    expect(recipients.map(&:code)).to eq(%w[apex])
  end
end
