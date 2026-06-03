module Leads
  module Qualification
    module Rules
      class NotPreviouslyDroppedOrSettledRule < BooleanPrequalRule
        CODE = "not_previously_dropped_or_settled"
        FIELD = :not_previously_dropped_or_settled
        MESSAGE = "Claim must not have been previously dropped or settled"
      end
    end
  end
end
