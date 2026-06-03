module Leads
  module Qualification
    class Evaluator
      def self.call(lead)
        new(lead).call
      end

      def initialize(lead, rules: RuleSet.rules)
        @lead = lead
        @rules = rules
      end

      def call
        passed_rule_codes = []
        failed_rules = []

        rules.each do |rule_class|
          rule = rule_class.new
          failure = rule.call(lead)

          if failure
            failed_rules << failure
          else
            passed_rule_codes << rule.code
          end
        end

        Result.new(passed_rule_codes, failed_rules)
      end

      private

      attr_reader :lead, :rules
    end
  end
end
