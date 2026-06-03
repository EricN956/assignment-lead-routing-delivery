module Leads
  module Qualification
    class RuleSet
      RULES = [
        Rules::HasInjuriesRule,
        Rules::NotAtFaultRule,
        Rules::WithinOneYearRule,
        Rules::HasNoAttorneyRule,
        Rules::NotPreviouslyDroppedOrSettledRule,
        Rules::HasReceivedMedicalTreatmentRule
      ].freeze

      def self.rules
        RULES
      end
    end
  end
end
