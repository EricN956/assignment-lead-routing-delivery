module Leads
  module Routing
    class RecipientSelector
      def self.call(lead)
        new(lead).call
      end

      def initialize(lead, recipients: Recipient.active.ordered_for_routing)
        @lead = lead
        @recipients = recipients
      end

      def call
        return Recipient.none unless lead.accident_state.present?

        recipients.select do |recipient|
          recipient.routing_eligible_for?(lead)
        end
      end

      private

      attr_reader :lead, :recipients
    end
  end
end
