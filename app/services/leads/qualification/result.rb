module Leads
  module Qualification
    Result = Data.define(:passed_rule_codes, :failed_rules) do
      def qualified?
        failed_rules.empty?
      end

      def disqualified?
        !qualified?
      end

      def failed_rule_codes
        failed_rules.map(&:code)
      end

      def failed_rule_hashes
        failed_rules.map(&:to_h)
      end

      def to_h
        {
          "passed_rules" => passed_rule_codes,
          "failed_rules" => failed_rule_hashes
        }
      end
    end
  end
end
