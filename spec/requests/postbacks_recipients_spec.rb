require "rails_helper"

RSpec.describe "Recipient postbacks", type: :request do
  let(:lead) do
    Lead.create!(
      source_claim_id: "RAV-POSTBACK-REQ-1",
      publisher: "publisher_alpha",
      stage: "delivered"
    )
  end

  let(:recipient) do
    Recipient.create!(
      code: "beacon",
      name: "Beacon Claims",
      accepted_states: %w[TX],
      base_url: "http://localhost:3100",
      endpoint_path: "/beacon/api/addLead",
      auth_type: "api_key",
      client_class: "Recipients::BeaconClient"
    )
  end

  let(:payload) do
    {
      recipient: recipient.code,
      source_claim_id: lead.source_claim_id,
      external_id: "BCN123456",
      disposition: "signed",
      occurred_at: "2026-06-01T08:16:11Z",
      signature: "abc123"
    }
  end

  it "accepts valid recipient postbacks" do
    post "/postbacks/recipients", params: payload, as: :json

    expect(response).to have_http_status(:accepted)

    body = JSON.parse(response.body)
    expect(body).to include(
      "status" => "accepted",
      "message" => "postback accepted"
    )
    expect(lead.reload.latest_stage_event.reason).to eq("recipient_postback_received")
  end

  it "returns accepted for unknown source claim ids" do
    recipient

    post "/postbacks/recipients",
         params: payload.merge(source_claim_id: "RAV-UNKNOWN"),
         as: :json

    expect(response).to have_http_status(:accepted)

    body = JSON.parse(response.body)
    expect(body).to include(
      "status" => "ignored",
      "message" => "unknown_source_claim_id"
    )
  end

  it "returns unprocessable entity for invalid payloads" do
    post "/postbacks/recipients",
         params: payload.except(:recipient),
         as: :json

    expect(response).to have_http_status(:unprocessable_entity)

    body = JSON.parse(response.body)
    expect(body["errors"]).to include(
      "recipient" => ["is required"]
    )
  end
end
