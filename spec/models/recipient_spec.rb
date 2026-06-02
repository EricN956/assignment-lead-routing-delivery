require "rails_helper"

RSpec.describe Recipient, type: :model do
  subject(:recipient) do
    described_class.new(
      code: "apex",
      name: "Apex Legal Intake",
      accepted_states: %w[TX FL],
      base_url: "http://localhost:3100/",
      endpoint_path: "/apex/v2/leads",
      auth_type: "api_key",
      client_class: "Recipients::ApexClient"
    )
  end

  it "is valid with routing and integration configuration" do
    expect(recipient).to be_valid
  end

  it "requires a unique code" do
    recipient.save!

    duplicate = recipient.dup
    duplicate.name = "Duplicate Apex"

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:code]).to be_present
  end

  it "normalizes accepted states before validation" do
    recipient.accepted_states = [" tx ", "fl", "TX", ""]

    expect(recipient).to be_valid
    expect(recipient.accepted_states).to eq(%w[TX FL])
  end

  it "detects whether a state is accepted" do
    expect(recipient.accepts_state?("tx")).to be(true)
    expect(recipient.accepts_state?("WY")).to be(false)
  end

  it "builds a stable endpoint URL" do
    expect(recipient.endpoint_url).to eq("http://localhost:3100/apex/v2/leads")
  end

  it "rejects invalid state codes" do
    recipient.accepted_states = ["Texas"]

    expect(recipient).not_to be_valid
    expect(recipient.errors[:accepted_states]).to be_present
  end

  it "knows whether the daily cap is reached" do
    recipient.daily_cap = 1
    recipient.save!

    lead = Lead.create!(
      source_claim_id: "RAV-CAP-1",
      publisher: "publisher_alpha"
    )

    LeadDelivery.create!(
      lead: lead,
      recipient: recipient,
      status: "delivered",
      delivered_at: Time.current
    )

    expect(recipient.daily_cap_reached?).to be(true)
  end

  it "knows if it is eligible to route a lead" do
    recipient.save!

    lead = Lead.new(accident_state: "TX")

    expect(recipient.routing_eligible_for?(lead)).to be(true)
  end
end
