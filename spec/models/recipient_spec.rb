require "rails_helper"

RSpec.describe Recipient, type: :model do
  subject(:recipient) do
    described_class.new(
      code: "apex",
      name: "Apex Legal Intake",
      accepted_states: %w[TX FL],
      base_url: "http://localhost:3100",
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

  it "detects whether a state is accepted" do
    expect(recipient.accepts_state?("tx")).to be(true)
    expect(recipient.accepts_state?("WY")).to be(false)
  end

  it "rejects invalid state codes" do
    recipient.accepted_states = ["Texas"]

    expect(recipient).not_to be_valid
    expect(recipient.errors[:accepted_states]).to be_present
  end
end
