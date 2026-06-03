module Leads
  module Qualification
    module Rules
      class WithinOneYearRule < BooleanPrequalRule
        CODE = "within_1_year"
        FIELD = :within_1_year
        MESSAGE = "Incident must be within one year"
      end
    end
  end
end
