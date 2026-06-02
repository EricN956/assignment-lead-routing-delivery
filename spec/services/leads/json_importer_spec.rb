require "rails_helper"
require "tempfile"

RSpec.describe Leads::JsonImporter do
  def write_json(payloads)
    file = Tempfile.new(["leads", ".json"])
    file.write(JSON.generate(payloads))
    file.close
    file
  end

  let(:valid_payload) do
    {
      "source_claim_id" => "RAV-IMPORT-1",
      "publisher" => "publisher_alpha",
      "received_at" => "2026-05-31T09:00:00Z",
      "first_name" => "Jordan",
      "last_name" => "Carter",
      "phone" => "+1 (555) 314-2271",
      "email" => "user1001@example.com",
      "accident_state" => "TX",
      "incident_date" => "2026-04-02",
      "lead_type" => "accident_case",
      "prequal" => { "has_injuries" => true }
    }
  end

  after do
    @file&.unlink
  end

  it "creates a validated lead from a valid payload" do
    @file = write_json([valid_payload])

    summary = described_class.call(@file.path)

    lead = Lead.find_by!(source_claim_id: "RAV-IMPORT-1")

    expect(summary.to_h).to include(
      "total" => 1,
      "created" => 1,
      "valid" => 1,
      "invalid" => 0,
      "duplicates" => 0,
      "failed" => 0
    )
    expect(lead).to have_attributes(
      stage: "validated",
      phone: "5553142271",
      email: "user1001@example.com"
    )
    expect(lead.stage_events.pluck(:to_stage)).to eq(%w[received validated])
  end

  it "creates an invalid lead with structured validation errors" do
    @file = write_json([
      valid_payload.merge(
        "source_claim_id" => "RAV-IMPORT-INVALID",
        "email" => "",
        "phone" => "(555) 123-99"
      )
    ])

    summary = described_class.call(@file.path)

    lead = Lead.find_by!(source_claim_id: "RAV-IMPORT-INVALID")

    expect(summary.to_h).to include(
      "total" => 1,
      "created" => 1,
      "valid" => 0,
      "invalid" => 1,
      "failed" => 0
    )
    expect(lead.stage).to eq("invalid")
    expect(lead.validation_errors).to include(
      "email" => ["is required"],
      "phone" => ["must normalize to 10 digits"]
    )
    expect(lead.invalid_reason).to eq("email, phone")
  end

  it "skips duplicate source claim ids safely" do
    Lead.create!(
      source_claim_id: "RAV-IMPORT-DUP",
      publisher: "publisher_alpha"
    )

    @file = write_json([
      valid_payload.merge("source_claim_id" => "RAV-IMPORT-DUP")
    ])

    summary = described_class.call(@file.path)

    expect(summary.to_h).to include(
      "total" => 1,
      "created" => 0,
      "duplicates" => 1,
      "failed" => 0
    )
  end

  it "imports sample JSON with expected deterministic counts" do
    summary = described_class.call(Rails.root.join("data/inbound_leads.json"))

    expect(summary.total).to eq(25)
    expect(summary.created).to eq(24)
    expect(summary.valid).to eq(20)
    expect(summary.invalid).to eq(4)
    expect(summary.duplicates).to eq(1)
    expect(summary.failed).to eq(0)
  end

  it "raises a clear error for non-array JSON" do
    @file = write_json({ "source_claim_id" => "RAV-NOT-ARRAY" })

    expect do
      described_class.call(@file.path)
    end.to raise_error(ArgumentError, /must be an array/)
  end
end
