require "rails_helper"

RSpec.describe Postbacks::RecipientReceiver do
  let(:lead) do
    Lead.create!(
      source_claim_id: "RAV-POSTBACK-1",
      publisher: "publisher_alpha",
      stage: "delivered"
    )
  end

  let(:recipient) do
    Recipient.create!(
      code: "apex",
      name: "Apex Legal Intake",
      accepted_states: %w[TX],
      base_url: "http://localhost:3100",
      endpoint_path: "/apex/v2/leads",
      auth_type: "api_key",
      client_class: "Recipients::ApexClient"
    )
  end

  let(:payload) do
    {
      recipient: recipient.code,
      source_claim_id: lead.source_claim_id,
      external_id: "APX-1234",
      disposition: "signed",
      occurred_at: "2026-06-01T08:16:11Z",
      signature: "abc123"
    }
  end

  it "records an audit event for known lead and recipient" do
    result = described_class.call(payload)

    expect(result).to be_accepted
    expect(result.http_status).to eq(:accepted)

    event = lead.reload.latest_stage_event
    expect(event).to have_attributes(
      from_stage: "delivered",
      to_stage: "delivered",
      reason: "recipient_postback_received"
    )
    expect(event.metadata).to include(
      "recipient" => "apex",
      "source_claim_id" => "RAV-POSTBACK-1",
      "external_id" => "APX-1234",
      "disposition" => "signed",
      "signature_present" => true
    )
  end

  it "gracefully ignores unknown source claim ids" do
    recipient
    result = described_class.call(payload.merge(source_claim_id: "RAV-UNKNOWN"))

    expect(result).to be_ignored
    expect(result.http_status).to eq(:accepted)
    expect(result.message).to eq("unknown_source_claim_id")
  end

  it "gracefully ignores unknown recipients" do
    lead
    result = described_class.call(payload.merge(recipient: "unknown"))

    expect(result).to be_ignored
    expect(result.http_status).to eq(:accepted)
    expect(result.message).to eq("unknown_recipient")
  end

  it "rejects missing required fields" do
    result = described_class.call(payload.except(:source_claim_id, :signature))

    expect(result).to be_invalid
    expect(result.http_status).to eq(:unprocessable_entity)
    expect(result.errors).to include(
      "source_claim_id" => ["is required"],
      "signature" => ["is required"]
    )
  end

  it "rejects unsupported dispositions" do
    result = described_class.call(payload.merge(disposition: "maybe"))

    expect(result).to be_invalid
    expect(result.errors["disposition"]).to include("is not supported")
  end
end
