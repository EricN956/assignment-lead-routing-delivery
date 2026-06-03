require "rails_helper"

RSpec.describe Recipients::CitadelClient do
  let(:recipient) do
    Recipient.create!(
      code: "citadel",
      name: "Citadel Case Desk",
      accepted_states: %w[FL GA CA NY],
      base_url: "http://localhost:3100",
      endpoint_path: "/citadel/intake",
      auth_type: "bearer_token",
      client_class: "Recipients::CitadelClient",
      settings: {
        "bearer_token" => "citadel-test-token-789"
      }
    )
  end

  let(:lead) do
    Lead.create!(
      source_claim_id: "RAV-CITADEL-1",
      publisher: "publisher_alpha",
      first_name: "Jordan",
      last_name: "Carter",
      phone: "5553386115",
      email: "jordan@example.com",
      accident_state: "FL",
      incident_date: Date.iso8601("2026-04-02"),
      injuries: "neck and back pain",
      lead_type: "accident_case",
      stage: "routed"
    )
  end

  subject(:client) { described_class.new(recipient: recipient) }

  it "posts Citadel JSON payload and returns accepted result" do
    stub = stub_request(:post, "http://localhost:3100/citadel/intake")
      .with(
        headers: {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer citadel-test-token-789"
        },
        body: {
          source_claim_id: "RAV-CITADEL-1",
          first_name: "Jordan",
          last_name: "Carter",
          phone: "5553386115",
          email: "jordan@example.com",
          accident_state: "FL",
          injuries: "neck and back pain"
        }.to_json
      )
      .to_return(
        status: 200,
        body: { accepted: true, external_id: "CIT-12345" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = client.deliver(lead)

    expect(stub).to have_been_requested
    expect(result).to be_accepted
    expect(result.delivery_status).to eq("delivered")
    expect(result.external_id).to eq("CIT-12345")
    expect(result.request["headers"]).to eq("Authorization" => "[FILTERED]")
    expect(result.response["status"]).to eq(200)
  end

  it "treats duplicate 409 responses as duplicate accepted" do
    stub_request(:post, "http://localhost:3100/citadel/intake")
      .to_return(
        status: 409,
        body: { error: "duplicate", source_claim_id: "RAV-CITADEL-1" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = client.deliver(lead)

    expect(result).to be_duplicate_accepted
    expect(result).to be_successful
    expect(result.delivery_status).to eq("duplicate_accepted")
    expect(result.external_id).to eq("RAV-CITADEL-1")
    expect(result.metadata["source_claim_id"]).to eq("RAV-CITADEL-1")
  end

  it "returns retryable failure for rate limited responses" do
    stub_request(:post, "http://localhost:3100/citadel/intake")
      .to_return(
        status: 429,
        body: { error: "rate_limited" }.to_json,
        headers: {
          "Content-Type" => "application/json",
          "Retry-After" => "3"
        }
      )

    result = client.deliver(lead)

    expect(result).to be_retryable
    expect(result.delivery_status).to eq("retrying")
    expect(result.error_code).to eq("rate_limited")
    expect(result.retry_after_seconds).to eq(3)
    expect(result.error_message).to eq("Citadel rate limit reached")
  end

  it "returns permanent failure for unauthorized responses" do
    stub_request(:post, "http://localhost:3100/citadel/intake")
      .to_return(
        status: 401,
        body: { error: "unauthorized" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = client.deliver(lead)

    expect(result).to be_permanent_failure
    expect(result.delivery_status).to eq("failed")
    expect(result.error_code).to eq("unauthorized")
    expect(result.error_message).to eq("Citadel authentication failed")
  end

  it "returns permanent failure for validation responses" do
    stub_request(:post, "http://localhost:3100/citadel/intake")
      .to_return(
        status: 422,
        body: { error: "validation_failed", missing: ["email"] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = client.deliver(lead)

    expect(result).to be_permanent_failure
    expect(result.error_code).to eq("validation_failed")
    expect(result.error_message).to eq("Citadel validation failed")
    expect(result.metadata["missing"]).to eq(["email"])
  end

  it "returns retryable failure for unexpected 5xx responses" do
    stub_request(:post, "http://localhost:3100/citadel/intake")
      .to_return(
        status: 500,
        body: { error: "internal_error" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = client.deliver(lead)

    expect(result).to be_retryable
    expect(result.delivery_status).to eq("retrying")
    expect(result.error_code).to eq("internal_error")
  end

  it "can be built through the client registry" do
    built_client = Recipients::ClientRegistry.build(recipient)

    expect(built_client).to be_a(described_class)
    expect(built_client.recipient).to eq(recipient)
  end
end
