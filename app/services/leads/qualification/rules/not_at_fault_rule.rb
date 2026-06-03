module Leads
  module Qualification
    module Rules
      class NotAtFaultRule < BooleanPrequalRule
        CODE = "not_at_fault"
        FIELD = :not_at_fault
        MESSAGE = "Lead must indicate claimant was not at fault"
      end
    end
  end
end
