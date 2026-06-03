require "rails_helper"

RSpec.describe Recipients::BeaconClient do
  let(:recipient) do
    Recipient.create!(
      code: "beacon",
      name: "Beacon Claims",
      accepted_states: %w[TX CA NY AZ NV],
      base_url: "http://localhost:3100",
      endpoint_path: "/beacon/api/addLead",
      auth_type: "api_key",
      client_class: "Recipients::BeaconClient",
      settings: {
        "api_key" => "beacon-test-key-456",
        "api_key_field" => "key",
        "case_type" => "auto_accident"
      }
    )
  end

  let(:lead) do
    Lead.create!(
      source_claim_id: "RAV-BEACON-1",
      publisher: "publisher_alpha",
      first_name: "Jordan",
      last_name: "Carter",
      phone: "+1 (555) 338-6115",
      email: "jordan@example.com",
      accident_state: "TX",
      incident_date: Date.iso8601("2026-04-02"),
      injuries: "neck and back pain",
      lead_type: "accident_case",
      stage: "routed"
    )
  end

  subject(:client) { described_class.new(recipient: recipient) }

  it "posts Beacon form payload and returns accepted result" do
    stub = stub_request(:post, "http://localhost:3100/beacon/api/addLead")
      .with(
        headers: {
          "Content-Type" => /application\/x-www-form-urlencoded/
        },
        body: {
          "key" => "beacon-test-key-456",
          "source_claim_id" => "RAV-BEACON-1",
          "first_name" => "Jordan",
          "last_name" => "Carter",
          "phone10" => "5553386115",
          "case_type" => "auto_accident"
        }
      )
      .to_return(
        status: 200,
        body: { success: 1, lead_id: "BCN123456" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = client.deliver(lead)

    expect(stub).to have_been_requested
    expect(result).to be_accepted
    expect(result.delivery_status).to eq("delivered")
    expect(result.external_id).to eq("BCN123456")
    expect(result.request["body"]["key"]).to eq("[FILTERED]")
    expect(result.response["status"]).to eq(200)
  end

  it "treats Beacon duplicate body response as duplicate accepted" do
    stub_request(:post, "http://localhost:3100/beacon/api/addLead")
      .to_return(
        status: 200,
        body: { success: 0, error: "duplicate" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = client.deliver(lead)

    expect(result).to be_duplicate_accepted
    expect(result).to be_successful
    expect(result.delivery_status).to eq("duplicate_accepted")
    expect(result.error_code).to be_nil
  end

  it "returns permanent failure for phone format rejections" do
    stub_request(:post, "http://localhost:3100/beacon/api/addLead")
      .to_return(
        status: 200,
        body: { success: 0, error: "phone_must_be_10_digits" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = client.deliver(lead)

    expect(result).to be_permanent_failure
    expect(result.delivery_status).to eq("failed")
    expect(result.error_code).to eq("phone_must_be_10_digits")
    expect(result.error_message).to eq("Beacon rejected the lead")
  end

  it "returns permanent failure for auth failures even though HTTP is 200" do
    stub_request(:post, "http://localhost:3100/beacon/api/addLead")
      .to_return(
        status: 200,
        body: { success: 0, error: "auth_failed" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = client.deliver(lead)

    expect(result).to be_permanent_failure
    expect(result.error_code).to eq("auth_failed")
  end

  it "returns retryable failure for unexpected 5xx responses" do
    stub_request(:post, "http://localhost:3100/beacon/api/addLead")
      .to_return(
        status: 500,
        body: { error: "beacon_down" }.to_json,
        headers: {
          "Content-Type" => "application/json",
          "Retry-After" => "2"
        }
      )

    result = client.deliver(lead)

    expect(result).to be_retryable
    expect(result.delivery_status).to eq("retrying")
    expect(result.error_code).to eq("beacon_down")
    expect(result.retry_after_seconds).to eq(2)
  end

  it "can be built through the client registry" do
    built_client = Recipients::ClientRegistry.build(recipient)

    expect(built_client).to be_a(described_class)
    expect(built_client.recipient).to eq(recipient)
  end
end
