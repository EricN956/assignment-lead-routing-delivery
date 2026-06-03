require "rails_helper"

RSpec.describe "Recipient postbacks", type: :request do
  def signature_for(source_claim_id:, disposition:)
    Digest::SHA256.hexdigest("#{source_claim_id}:#{disposition}:mock-shared-secret")
  end

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
      signature: signature_for(source_claim_id: lead.source_claim_id, disposition: "signed")
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
    expect(lead.reload.stage).to eq("converted")
    expect(Conversion.where(lead: lead, recipient: recipient, disposition: "signed").count).to eq(1)
  end

  it "returns accepted for unknown source claim ids" do
    recipient

    post "/postbacks/recipients",
         params: payload.merge(
      source_claim_id: "RAV-UNKNOWN",
      signature: signature_for(source_claim_id: "RAV-UNKNOWN", disposition: "signed")
    ),
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

    expect(response).to have_http_status(:unprocessable_content)

    body = JSON.parse(response.body)
    expect(body["errors"]).to include(
      "recipient" => ["is required"]
    )
  end
  it "returns unauthorized for invalid signatures" do
    post "/postbacks/recipients",
         params: payload.merge(signature: "bad-signature"),
         as: :json

    expect(response).to have_http_status(:unauthorized)

    body = JSON.parse(response.body)
    expect(body).to include(
      "status" => "invalid_signature",
      "message" => "postback signature invalid"
    )
    expect(body["errors"]).to include(
      "signature" => ["is invalid"]
    )
  end
end
