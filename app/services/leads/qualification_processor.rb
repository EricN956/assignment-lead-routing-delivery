module Leads
  class QualificationProcessor
    def self.call(lead)
      new(lead).call
    end

    def initialize(lead, evaluator: Qualification::Evaluator)
      @lead = lead
      @evaluator = evaluator
    end

    def call
      return lead unless lead.stage == "scrubbed"

      if lead.test_lead?
        mark_test_lead
      else
        process_intake_rules
      end

      lead
    end

    private

    attr_reader :lead, :evaluator

    def mark_test_lead
      lead.transition_to!(
        "test",
        reason: "test_lead_skipped",
        metadata: {
          "test_lead" => true,
          "processor" => self.class.name
        }
      )
    end

    def process_intake_rules
      result = evaluator.call(lead)

      if result.qualified?
        lead.update!(disqualification_reasons: [])
        lead.transition_to!(
          "qualified",
          reason: "qualification_passed",
          metadata: result.to_h.merge("processor" => self.class.name)
        )
      else
        lead.update!(disqualification_reasons: result.failed_rule_hashes)
        lead.transition_to!(
          "disqualified",
          reason: "qualification_failed",
          metadata: result.to_h.merge("processor" => self.class.name)
        )
      end
    end
  end
end
