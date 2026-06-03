require "rails_helper"

RSpec.describe Leads::Qualification::Evaluator do
  def build_lead(prequal)
    Lead.new(
      source_claim_id: "RAV-QUAL-EVAL",
      publisher: "publisher_alpha",
      prequal: prequal
    )
  end

  let(:passing_prequal) do
    {
      "has_injuries" => true,
      "not_at_fault" => true,
      "within_1_year" => true,
      "has_no_attorney" => true,
      "not_previously_dropped_or_settled" => true,
      "has_received_medical_treatment" => true
    }
  end

  it "returns qualified when every intake rule passes" do
    result = described_class.call(build_lead(passing_prequal))

    expect(result).to be_qualified
    expect(result.failed_rule_codes).to eq([])
    expect(result.passed_rule_codes).to contain_exactly(
      "has_injuries",
      "not_at_fault",
      "within_1_year",
      "has_no_attorney",
      "not_previously_dropped_or_settled",
      "has_received_medical_treatment"
    )
  end

  it "returns failed rule details when prequal values are false" do
    result = described_class.call(
      build_lead(
        passing_prequal.merge(
          "within_1_year" => false,
          "has_no_attorney" => false
        )
      )
    )

    expect(result).to be_disqualified
    expect(result.failed_rule_codes).to contain_exactly(
      "within_1_year",
      "has_no_attorney"
    )
    expect(result.failed_rule_hashes.first).to include(
      "field",
      "message",
      "expected",
      "actual"
    )
  end

  it "treats missing prequal values as failed rules" do
    result = described_class.call(build_lead({}))

    expect(result).to be_disqualified
    expect(result.failed_rule_codes).to contain_exactly(
      "has_injuries",
      "not_at_fault",
      "within_1_year",
      "has_no_attorney",
      "not_previously_dropped_or_settled",
      "has_received_medical_treatment"
    )
  end
end
