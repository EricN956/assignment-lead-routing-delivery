require "rails_helper"

RSpec.describe Postbacks::RecipientReceiver do
  def signature_for(source_claim_id:, disposition:)
    Digest::SHA256.hexdigest("#{source_claim_id}:#{disposition}:mock-shared-secret")
  end

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
      signature: signature_for(source_claim_id: lead.source_claim_id, disposition: "signed")
    }
  end

  it "records an audit event for known lead and recipient" do
    result = described_class.call(payload)

    expect(result).to be_accepted
    expect(result.http_status).to eq(:accepted)

    event = lead.reload.stage_events.find_by!(reason: "recipient_postback_received")
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
      "signature_present" => true,
      "signature_verified" => true
    )
  end

  it "gracefully ignores unknown source claim ids" do
    recipient
    result = described_class.call(payload.merge(
      source_claim_id: "RAV-UNKNOWN",
      signature: signature_for(source_claim_id: "RAV-UNKNOWN", disposition: "signed")
    ))

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
  it "records a conversion for known lead and recipient" do
    result = described_class.call(payload)

    expect(result).to be_accepted
    expect(Conversion.where(lead: lead, recipient: recipient, disposition: "signed").count).to eq(1)
    expect(lead.reload.stage).to eq("converted")
  end

  it "does not duplicate conversions for repeated postbacks" do
    described_class.call(payload)
    described_class.call(payload)

    expect(Conversion.where(lead: lead, recipient: recipient).count).to eq(1)
    expect(lead.stage_events.where(reason: "duplicate_postback_ignored").count).to eq(1)
  end
  it "rejects invalid signatures before recording conversions" do
    result = described_class.call(payload.merge(signature: "bad-signature"))

    expect(result).to be_invalid_signature
    expect(result.http_status).to eq(:unauthorized)
    expect(Conversion.where(lead: lead, recipient: recipient).count).to eq(0)
    expect(lead.reload.stage).to eq("delivered")
  end
end
