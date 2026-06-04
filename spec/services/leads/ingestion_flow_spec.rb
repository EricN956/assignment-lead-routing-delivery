require "rails_helper"

RSpec.describe "Lead ingestion validation flow" do
  def sample_ids
    JSON.parse(File.read(Rails.root.join("data/inbound_leads.json")))
      .map { |row| row["source_claim_id"] }
      .compact
      .uniq
  end

  def import_sample
    Leads::JsonImporter.call(Rails.root.join("data/inbound_leads.json"))
  end

  it "imports the sample file with deterministic validation counts" do
    summary = import_sample

    expect(summary.to_h).to include(
      "total" => 25,
      "created" => 24,
      "valid" => 20,
      "invalid" => 4,
      "duplicates" => 1,
      "failed" => 0
    )

    expect(Lead.where(source_claim_id: sample_ids).count).to eq(24)
    expect(Lead.where(source_claim_id: sample_ids, stage: "validated").count).to eq(20)
    expect(Lead.where(source_claim_id: sample_ids, stage: "invalid").count).to eq(4)
  end

  it "normalizes valid contact fields and preserves the raw payload" do
    import_sample

    lead = Lead.find_by!(source_claim_id: "RAV-1001")

    expect(lead).to have_attributes(
      stage: "validated",
      phone: "5553386115",
      email: "user1001@example.com",
      accident_state: "NY",
      test_lead: false
    )
    expect(lead.raw_payload).to include(
      "source_claim_id" => "RAV-1001",
      "publisher" => "publisher_charlie"
    )
    expect(lead.validation_errors).to eq({})
  end

  it "records validation lifecycle events for valid leads" do
    import_sample

    lead = Lead.find_by!(source_claim_id: "RAV-1001")

    ordered_events = lead.stage_events.order(:created_at, :id)

    expect(ordered_events.first(2).map(&:reason)).to eq(
      %w[
        lead_received
        ingest_validation_passed
      ]
    )
    expect(ordered_events.first(2).map(&:to_stage)).to eq(
      %w[
        received
        validated
      ]
    )
    expect(ordered_events.map(&:reason)).to include("duplicate_import_skipped")
  end

  it "stores structured validation errors for invalid leads" do
    import_sample

    missing_email = Lead.find_by!(source_claim_id: "RAV-1015")
    missing_phone = Lead.find_by!(source_claim_id: "RAV-1016")
    malformed_phone = Lead.find_by!(source_claim_id: "RAV-1017")
    broken = Lead.find_by!(source_claim_id: "RAV-BROKEN-1")

    expect(missing_email).to have_attributes(
      stage: "invalid",
      invalid_reason: "email"
    )
    expect(missing_email.validation_errors).to eq(
      "email" => ["is required"]
    )

    expect(missing_phone.validation_errors).to eq(
      "phone" => ["is required"]
    )

    expect(malformed_phone.validation_errors).to eq(
      "phone" => ["must normalize to 10 digits"]
    )

    expect(broken.validation_errors.keys).to contain_exactly(
      "last_name",
      "phone",
      "email",
      "accident_state",
      "incident_date",
      "lead_type",
      "prequal"
    )
  end

  it "records invalid lifecycle events with validation metadata" do
    import_sample

    lead = Lead.find_by!(source_claim_id: "RAV-1015")
    event = lead.stage_events.find_by!(reason: "ingest_validation_failed")

    expect(event).to have_attributes(
      from_stage: "received",
      to_stage: "invalid"
    )
    expect(event.metadata).to include(
      "importer" => "Leads::JsonImporter",
      "path" => "data/inbound_leads.json"
    )
    expect(event.metadata.fetch("errors")).to eq(
      "email" => ["is required"]
    )
  end

  it "is idempotent on re-import and records duplicate audit events" do
    first_summary = import_sample
    second_summary = import_sample

    expect(first_summary.created).to eq(24)
    expect(second_summary.to_h).to include(
      "total" => 25,
      "created" => 0,
      "valid" => 0,
      "invalid" => 0,
      "duplicates" => 25,
      "failed" => 0
    )

    lead = Lead.find_by!(source_claim_id: "RAV-1001")
    duplicate_event = lead.stage_events.where(reason: "duplicate_import_skipped").last

    expect(duplicate_event).to be_present
    expect(duplicate_event).to have_attributes(
      from_stage: "validated",
      to_stage: "validated"
    )
    expect(duplicate_event.metadata).to include(
      "importer" => "Leads::JsonImporter",
      "source_claim_id" => "RAV-1001",
      "existing_stage" => "validated"
    )
  end
end
