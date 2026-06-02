require "rails_helper"

RSpec.describe Lead, type: :model do
  subject(:lead) do
    described_class.new(
      source_claim_id: "RAV-TEST-1",
      publisher: "publisher_alpha",
      first_name: "Casey",
      last_name: "Foster",
      phone: "5553386115",
      email: "casey@example.com"
    )
  end

  it "is valid with required CRM identity fields" do
    expect(lead).to be_valid
  end

  it "requires a source claim id" do
    lead.source_claim_id = nil

    expect(lead).not_to be_valid
    expect(lead.errors[:source_claim_id]).to be_present
  end

  it "requires a publisher" do
    lead.publisher = nil

    expect(lead).not_to be_valid
    expect(lead.errors[:publisher]).to be_present
  end

  it "records the initial lifecycle event on create" do
    lead.save!

    expect(lead.stage).to eq("received")
    expect(lead.stage_events.count).to eq(1)

    event = lead.stage_events.first
    expect(event.from_stage).to be_nil
    expect(event.to_stage).to eq("received")
    expect(event.reason).to eq("lead_received")
  end

  it "transitions to a new stage with an audit event" do
    lead.save!

    lead.transition_to!(
      "validated",
      reason: "required_fields_present",
      metadata: { "validator" => "LeadValidator" }
    )

    expect(lead.stage).to eq("validated")
    expect(lead.stage_events.order(:created_at).last).to have_attributes(
      from_stage: "received",
      to_stage: "validated",
      reason: "required_fields_present"
    )
  end

  it "rejects unsupported stages" do
    lead.save!

    expect do
      lead.transition_to!("unknown", reason: "bad_stage")
    end.to raise_error(ArgumentError, /Unsupported lead stage/)
  end

  it "returns a displayable full name" do
    expect(lead.full_name).to eq("Casey Foster")
  end
  it "knows whether it is dispatchable" do
    lead.stage = "qualified"

    expect(lead).to be_dispatchable

    lead.test_lead = true

    expect(lead).not_to be_dispatchable
  end

  it "knows whether it is terminal" do
    lead.stage = "converted"

    expect(lead).to be_terminal
  end
  it "records audit events without changing the current stage" do
    lead.save!

    lead.record_stage_event!(
      reason: "duplicate_import_skipped",
      metadata: { "importer" => "Leads::JsonImporter" }
    )

    expect(lead.reload.stage).to eq("received")
    expect(lead.latest_stage_event).to have_attributes(
      from_stage: "received",
      to_stage: "received",
      reason: "duplicate_import_skipped"
    )
  end
end
