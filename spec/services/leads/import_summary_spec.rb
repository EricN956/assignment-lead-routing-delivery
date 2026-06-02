require "rails_helper"

RSpec.describe Leads::ImportSummary do
  it "tracks import counters" do
    summary = described_class.new

    summary.increment_total
    summary.record_valid
    summary.record_duplicate

    expect(summary.to_h).to include(
      "total" => 1,
      "created" => 1,
      "valid" => 1,
      "invalid" => 0,
      "duplicates" => 1,
      "failed" => 0
    )
  end
end
