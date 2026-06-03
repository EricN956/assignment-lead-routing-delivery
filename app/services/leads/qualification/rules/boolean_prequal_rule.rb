module Leads
  module Qualification
    module Rules
      class BooleanPrequalRule
        def call(lead)
          actual = lead.prequal.to_h[field.to_s]

          return nil if actual == true

          Failure.new(
            code: code,
            field: "prequal.#{field}",
            message: message,
            expected: true,
            actual: actual
          )
        end

        def code
          self.class::CODE
        end

        def field
          self.class::FIELD
        end

        def message
          self.class::MESSAGE
        end
      end
    end
  end
end
