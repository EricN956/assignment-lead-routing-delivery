module Leads
  module Qualification
    module Rules
      class HasNoAttorneyRule < BooleanPrequalRule
        CODE = "has_no_attorney"
        FIELD = :has_no_attorney
        MESSAGE = "Lead must not already have an attorney"
      end
    end
  end
end
