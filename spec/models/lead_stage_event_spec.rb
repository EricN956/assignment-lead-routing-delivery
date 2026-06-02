require "rails_helper"

RSpec.describe LeadStageEvent, type: :model do
  let(:lead) do
    Lead.create!(
      source_claim_id: "RAV-EVENT-1",
      publisher: "publisher_alpha"
    )
  end

  it "requires a supported to_stage" do
    event = described_class.new(
      lead: lead,
      from_stage: "received",
      to_stage: "not_real",
      reason: "bad_state",
      metadata: {}
    )

    expect(event).not_to be_valid
    expect(event.errors[:to_stage]).to be_present
  end

  it "allows a blank from_stage for the initial lifecycle event" do
    event = described_class.new(
      lead: lead,
      from_stage: nil,
      to_stage: "received",
      reason: "lead_received",
      metadata: {}
    )

    expect(event).to be_valid
  end
end
