module Leads
  module Qualification
    module Rules
      class HasReceivedMedicalTreatmentRule < BooleanPrequalRule
        CODE = "has_received_medical_treatment"
        FIELD = :has_received_medical_treatment
        MESSAGE = "Lead must have received medical treatment"
      end
    end
  end
end
