require "rails_helper"

RSpec.describe Recipients::BaseClient do
  let(:recipient) do
    Recipient.create!(
      code: "base_client_spec_#{SecureRandom.hex(4)}",
      name: "Base Client Spec",
      accepted_states: %w[TX],
      base_url: "http://localhost:3100/",
      endpoint_path: "/apex/v2/leads",
      auth_type: "api_key",
      client_class: "Recipients::BaseClientSpecClient"
    )
  end

  subject(:client) { described_class.new(recipient: recipient) }

  it "requires concrete clients to implement deliver" do
    expect do
      client.deliver(Lead.new)
    end.to raise_error(NotImplementedError, /must implement #deliver/)
  end

  it "exposes the recipient endpoint URL" do
    expect(client.endpoint_url).to eq("http://localhost:3100/apex/v2/leads")
  end

  it "redacts sensitive headers and payload keys recursively" do
    value = {
      "Authorization" => "Bearer secret",
      "X-Api-Key" => "secret-key",
      "safe" => "visible",
      "nested" => {
        "bearer_token" => "token-secret",
        "phone" => "5553386115"
      }
    }

    expect(client.redacted_hash(value)).to eq(
      "Authorization" => "[FILTERED]",
      "X-Api-Key" => "[FILTERED]",
      "safe" => "visible",
      "nested" => {
        "bearer_token" => "[FILTERED]",
        "phone" => "5553386115"
      }
    )
  end

  it "removes blank values from payloads recursively" do
    payload = {
      name: "Jordan",
      email: "",
      nested: {
        phone: "5553386115",
        blank: nil
      }
    }

    expect(client.compact_payload(payload)).to eq(
      name: "Jordan",
      nested: {
        phone: "5553386115"
      }
    )
  end

  it "parses retry-after seconds" do
    expect(client.retry_after_seconds("Retry-After" => "45")).to eq(45)
  end

  it "builds redacted request snapshots" do
    snapshot = client.request_snapshot(
      method: "post",
      url: client.endpoint_url,
      headers: { "X-Api-Key" => "secret" },
      body: { "source_claim_id" => "RAV-1" }
    )

    expect(snapshot).to include(
      "method" => "POST",
      "url" => "http://localhost:3100/apex/v2/leads"
    )
    expect(snapshot["headers"]).to eq("X-Api-Key" => "[FILTERED]")
  end
end
