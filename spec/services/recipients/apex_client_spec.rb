require "rails_helper"

RSpec.describe Recipients::ApexClient do
  let(:recipient) do
    Recipient.create!(
      code: "apex",
      name: "Apex Legal Intake",
      accepted_states: %w[TX FL GA NC OH],
      base_url: "http://localhost:3100",
      endpoint_path: "/apex/v2/leads",
      auth_type: "api_key",
      client_class: "Recipients::ApexClient",
      settings: {
        "api_key" => "apex-test-key-123",
        "auth_header" => "X-Api-Key"
      }
    )
  end

  let(:lead) do
    Lead.create!(
      source_claim_id: "RAV-APEX-1",
      publisher: "publisher_alpha",
      first_name: "Jordan",
      last_name: "Carter",
      phone: "5553386115",
      email: "jordan@example.com",
      accident_state: "TX",
      incident_date: Date.iso8601("2026-04-02"),
      injuries: "neck and back pain",
      lead_type: "accident_case",
      stage: "routed"
    )
  end

  subject(:client) { described_class.new(recipient: recipient) }

  it "builds the Apex nested JSON payload and returns accepted result" do
    stub = stub_request(:post, "http://localhost:3100/apex/v2/leads")
      .with(
        headers: {
          "Content-Type" => "application/json",
          "X-Api-Key" => "apex-test-key-123"
        },
        body: {
          source_claim_id: "RAV-APEX-1",
          claim: {
            first_name: "Jordan",
            last_name: "Carter",
            phone: "5553386115",
            email: "jordan@example.com"
          },
          incident: {
            state: "TX",
            date: "2026-04-02",
            injuries: "neck and back pain"
          }
        }.to_json
      )
      .to_return(
        status: 202,
        body: { claim_id: "APX-1234", status: "accepted" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = client.deliver(lead)

    expect(stub).to have_been_requested
    expect(result).to be_accepted
    expect(result.delivery_status).to eq("delivered")
    expect(result.external_id).to eq("APX-1234")
    expect(result.request["headers"]).to eq("X-Api-Key" => "[FILTERED]")
    expect(result.response["status"]).to eq(202)
  end

  it "returns retryable failure for Apex 503 responses" do
    stub_request(:post, "http://localhost:3100/apex/v2/leads")
      .to_return(
        status: 503,
        body: { error: "upstream_unavailable" }.to_json,
        headers: {
          "Content-Type" => "application/json",
          "Retry-After" => "1"
        }
      )

    result = client.deliver(lead)

    expect(result).to be_retryable
    expect(result.delivery_status).to eq("retrying")
    expect(result.error_code).to eq("upstream_unavailable")
    expect(result.retry_after_seconds).to eq(1)
  end

  it "returns permanent failure for invalid API key responses" do
    stub_request(:post, "http://localhost:3100/apex/v2/leads")
      .to_return(
        status: 401,
        body: { error: "invalid_api_key" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = client.deliver(lead)

    expect(result).to be_permanent_failure
    expect(result.delivery_status).to eq("failed")
    expect(result.error_code).to eq("invalid_api_key")
    expect(result.error_message).to eq("Apex authentication failed")
  end

  it "returns permanent failure for validation responses" do
    stub_request(:post, "http://localhost:3100/apex/v2/leads")
      .to_return(
        status: 422,
        body: { error: "validation_failed", missing: ["claim.email"] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = client.deliver(lead)

    expect(result).to be_permanent_failure
    expect(result.error_code).to eq("validation_failed")
    expect(result.metadata["missing"]).to eq(["claim.email"])
  end

  it "can be built through the client registry" do
    built_client = Recipients::ClientRegistry.build(recipient)

    expect(built_client).to be_a(described_class)
    expect(built_client.recipient).to eq(recipient)
  end
end
