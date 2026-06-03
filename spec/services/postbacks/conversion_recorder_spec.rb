require "rails_helper"

RSpec.describe Postbacks::ConversionRecorder do
  def create_lead(stage: "delivered")
    Lead.create!(
      source_claim_id: "RAV-CONV-#{SecureRandom.hex(4)}",
      publisher: "publisher_alpha",
      stage: stage
    )
  end

  def create_recipient(code: "apex")
    Recipient.create!(
      code: "#{code}_#{SecureRandom.hex(4)}",
      name: "Postback Recipient",
      accepted_states: %w[TX],
      base_url: "http://localhost:3100",
      endpoint_path: "/postback",
      auth_type: "none",
      client_class: "Recipients::PostbackClient"
    )
  end

  def payload_for(lead:, recipient:, disposition: "signed", external_id: "EXT-123", signature: "sig-123")
    {
      "recipient" => recipient.code,
      "source_claim_id" => lead.source_claim_id,
      "external_id" => external_id,
      "disposition" => disposition,
      "occurred_at" => "2026-06-01T08:16:11Z",
      "signature" => signature
    }
  end

  it "creates a conversion record idempotently" do
    lead = create_lead
    recipient = create_recipient
    payload = payload_for(lead: lead, recipient: recipient)

    first = described_class.call(lead: lead, recipient: recipient, payload: payload)
    second = described_class.call(lead: lead, recipient: recipient, payload: payload)

    expect(first).to be_created
    expect(second).to be_duplicate
    expect(Conversion.where(lead: lead, recipient: recipient).count).to eq(1)
    expect(lead.stage_events.where(reason: "duplicate_postback_ignored").count).to eq(1)
  end

  it "moves signed leads to converted" do
    lead = create_lead(stage: "delivered")
    recipient = create_recipient

    result = described_class.call(
      lead: lead,
      recipient: recipient,
      payload: payload_for(lead: lead, recipient: recipient, disposition: "signed")
    )

    expect(result.conversion).to have_attributes(
      source_claim_id: lead.source_claim_id,
      disposition: "signed",
      external_id: "EXT-123"
    )
    expect(lead.reload.stage).to eq("converted")
    expect(lead.stage_events.where(reason: "recipient_conversion_signed")).to exist
    expect(lead.stage_events.where(reason: "conversion_recorded")).to exist
  end

  it "moves rejected delivered leads to rejected" do
    lead = create_lead(stage: "delivered")
    recipient = create_recipient

    described_class.call(
      lead: lead,
      recipient: recipient,
      payload: payload_for(lead: lead, recipient: recipient, disposition: "rejected")
    )

    expect(lead.reload.stage).to eq("rejected")
    expect(lead.latest_stage_event.reason).to eq("conversion_recorded")
    expect(lead.stage_events.where(reason: "recipient_conversion_rejected")).to exist
  end

  it "does not move already converted leads back to rejected" do
    lead = create_lead(stage: "converted")
    recipient = create_recipient

    described_class.call(
      lead: lead,
      recipient: recipient,
      payload: payload_for(lead: lead, recipient: recipient, disposition: "rejected")
    )

    expect(lead.reload.stage).to eq("converted")
  end

  it "updates matching delivery metadata when present" do
    lead = create_lead(stage: "delivered")
    recipient = create_recipient
    delivery = LeadDelivery.create!(
      lead: lead,
      recipient: recipient,
      status: "delivered",
      delivered_at: Time.current
    )

    result = described_class.call(
      lead: lead,
      recipient: recipient,
      payload: payload_for(lead: lead, recipient: recipient, disposition: "signed")
    )

    expect(delivery.reload.external_id).to eq("EXT-123")
    expect(delivery.metadata).to include(
      "latest_postback_disposition" => "signed",
      "latest_conversion_id" => result.conversion.id
    )
  end
end
