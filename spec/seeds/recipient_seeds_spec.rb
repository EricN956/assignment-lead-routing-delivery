require "rails_helper"

RSpec.describe "recipient seeds" do
  it "creates the configured recipient rows idempotently" do
    expect do
      Rails.application.load_seed
    end.to change(Recipient, :count).by(3)

    expect do
      Rails.application.load_seed
    end.not_to change(Recipient, :count)
  end

  it "seeds Apex with priority, cap, states, and API settings" do
    Rails.application.load_seed

    apex = Recipient.find_by!(code: "apex")

    expect(apex).to have_attributes(
      name: "Apex Legal Intake",
      active: true,
      priority: 1,
      daily_cap: 50,
      endpoint_path: "/apex/v2/leads",
      auth_type: "api_key",
      client_class: "Recipients::ApexClient"
    )
    expect(apex.accepted_states).to eq(%w[TX FL GA NC OH])
    expect(apex.settings["auth_header"]).to eq("X-Api-Key")
    expect(apex.settings["api_key"]).to eq("apex-test-key-123")
  end

  it "seeds Beacon with legacy form-encoded settings" do
    Rails.application.load_seed

    beacon = Recipient.find_by!(code: "beacon")

    expect(beacon).to have_attributes(
      priority: 2,
      daily_cap: 30,
      endpoint_path: "/beacon/api/addLead",
      auth_type: "api_key",
      client_class: "Recipients::BeaconClient"
    )
    expect(beacon.accepted_states).to eq(%w[TX CA NY AZ NV])
    expect(beacon.settings["content_type"]).to eq("application/x-www-form-urlencoded")
    expect(beacon.settings["api_key_field"]).to eq("key")
    expect(beacon.settings["api_key"]).to eq("beacon-test-key-456")
  end

  it "seeds Citadel with bearer-token settings" do
    Rails.application.load_seed

    citadel = Recipient.find_by!(code: "citadel")

    expect(citadel).to have_attributes(
      priority: 3,
      daily_cap: 20,
      endpoint_path: "/citadel/intake",
      auth_type: "bearer_token",
      client_class: "Recipients::CitadelClient"
    )
    expect(citadel.accepted_states).to eq(%w[FL GA CA NY])
    expect(citadel.settings["bearer_token"]).to eq("citadel-test-token-789")
  end
end
