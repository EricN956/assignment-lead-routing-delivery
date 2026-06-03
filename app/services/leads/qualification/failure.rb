module Leads
  module Qualification
    Failure = Data.define(:code, :field, :message, :expected, :actual) do
      def to_h
        {
          "code" => code,
          "field" => field,
          "message" => message,
          "expected" => expected,
          "actual" => actual
        }
      end
    end
  end
end
