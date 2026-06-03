module Leads
  module Qualification
    module Rules
      class HasInjuriesRule < BooleanPrequalRule
        CODE = "has_injuries"
        FIELD = :has_injuries
        MESSAGE = "Lead must report injuries"
      end
    end
  end
end
