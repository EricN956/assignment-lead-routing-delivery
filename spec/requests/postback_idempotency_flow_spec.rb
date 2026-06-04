require "rails_helper"

RSpec.describe "Postback idempotency flow", type: :request do
  def signature_for(source_claim_id:, disposition:)
    Digest::SHA256.hexdigest("#{source_claim_id}:#{disposition}:mock-shared-secret")
  end

  def create_lead(stage: "delivered")
    Lead.create!(
      source_claim_id: "RAV-POSTBACK-FLOW-#{SecureRandom.hex(4)}",
      publisher: "publisher_alpha",
      first_name: "Jordan",
      last_name: "Carter",
      phone: "5553386115",
      email: "postback-flow@example.com",
      accident_state: "TX",
      incident_date: Date.current,
      lead_type: "accident_case",
      stage: stage
    )
  end

  def create_recipient
    Recipient.create!(
      code: "postback_flow_#{SecureRandom.hex(4)}",
      name: "Postback Flow Recipient",
      accepted_states: %w[TX],
      base_url: "http://localhost:3100",
      endpoint_path: "/postback-flow",
      auth_type: "none",
      client_class: "Recipients::PostbackFlowClient"
    )
  end

  def payload_for(lead:, recipient:, disposition: "signed", external_id: "EXT-FLOW-1")
    {
      recipient: recipient.code,
      source_claim_id: lead.source_claim_id,
      external_id: external_id,
      disposition: disposition,
      occurred_at: "2026-06-01T08:16:11Z",
      signature: signature_for(
        source_claim_id: lead.source_claim_id,
        disposition: disposition
      )
    }
  end

  it "records one conversion for repeated identical signed postbacks" do
    lead = create_lead(stage: "delivered")
    recipient = create_recipient
    delivery = LeadDelivery.create!(
      lead: lead,
      recipient: recipient,
      status: "delivered",
      external_id: "EXT-FLOW-1",
      delivered_at: Time.current
    )
    payload = payload_for(lead: lead, recipient: recipient)

    post "/postbacks/recipients", params: payload, as: :json
    expect(response).to have_http_status(:accepted)

    post "/postbacks/recipients", params: payload, as: :json
    expect(response).to have_http_status(:accepted)

    expect(Conversion.where(lead: lead, recipient: recipient).count).to eq(1)
    expect(lead.reload.stage).to eq("converted")

    expect(lead.stage_events.where(reason: "recipient_postback_received").count).to eq(2)
    expect(lead.stage_events.where(reason: "recipient_conversion_signed").count).to eq(1)
    expect(lead.stage_events.where(reason: "conversion_recorded").count).to eq(1)
    expect(lead.stage_events.where(reason: "duplicate_postback_ignored").count).to eq(1)

    conversion = Conversion.find_by!(lead: lead, recipient: recipient)
    expect(delivery.reload.metadata).to include(
      "latest_postback_disposition" => "signed",
      "latest_conversion_id" => conversion.id
    )
  end

  it "does not create conversion records for invalid signatures" do
    lead = create_lead(stage: "delivered")
    recipient = create_recipient
    payload = payload_for(lead: lead, recipient: recipient).merge(
      signature: "bad-signature"
    )

    post "/postbacks/recipients", params: payload, as: :json

    expect(response).to have_http_status(:unauthorized)

    body = JSON.parse(response.body)
    expect(body).to include(
      "status" => "invalid_signature",
      "message" => "postback signature invalid"
    )

    expect(Conversion.where(lead: lead, recipient: recipient).count).to eq(0)
    expect(lead.reload.stage).to eq("delivered")
    expect(lead.stage_events.where(reason: "recipient_postback_received")).to be_empty
  end

  it "does not downgrade converted leads after a later rejected postback" do
    lead = create_lead(stage: "delivered")
    recipient = create_recipient

    signed_payload = payload_for(
      lead: lead,
      recipient: recipient,
      disposition: "signed",
      external_id: "EXT-SIGNED"
    )

    rejected_payload = payload_for(
      lead: lead,
      recipient: recipient,
      disposition: "rejected",
      external_id: "EXT-REJECTED"
    )

    post "/postbacks/recipients", params: signed_payload, as: :json
    expect(response).to have_http_status(:accepted)

    post "/postbacks/recipients", params: rejected_payload, as: :json
    expect(response).to have_http_status(:accepted)

    expect(lead.reload.stage).to eq("converted")
    expect(Conversion.where(lead: lead, recipient: recipient).pluck(:disposition)).to contain_exactly(
      "signed",
      "rejected"
    )
    expect(lead.stage_events.where(reason: "recipient_conversion_signed").count).to eq(1)
    expect(lead.stage_events.where(reason: "recipient_conversion_rejected")).to be_empty
  end

  it "accepts valid signed postbacks for unknown leads without creating conversions" do
    recipient = create_recipient
    source_claim_id = "RAV-UNKNOWN-POSTBACK-FLOW"
    payload = {
      recipient: recipient.code,
      source_claim_id: source_claim_id,
      external_id: "EXT-UNKNOWN",
      disposition: "signed",
      occurred_at: "2026-06-01T08:16:11Z",
      signature: signature_for(
        source_claim_id: source_claim_id,
        disposition: "signed"
      )
    }

    post "/postbacks/recipients", params: payload, as: :json

    expect(response).to have_http_status(:accepted)

    body = JSON.parse(response.body)
    expect(body).to include(
      "status" => "ignored",
      "message" => "unknown_source_claim_id"
    )
    expect(Conversion.where(source_claim_id: source_claim_id)).to be_empty
  end
end
