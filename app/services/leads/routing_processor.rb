module Leads
  class RoutingProcessor
    def self.call(lead)
      new(lead).call
    end

    def initialize(lead, selector: Routing::RecipientSelector)
      @lead = lead
      @selector = selector
    end

    def call
      return empty_result unless lead.stage == "qualified"

      recipients = Array(selector.call(lead))

      if recipients.empty?
        mark_unroutable
      else
        route_to(recipients)
      end
    end

    private

    attr_reader :lead, :selector

    def route_to(recipients)
      deliveries = recipients.map do |recipient|
        LeadDelivery.find_or_create_by!(lead: lead, recipient: recipient)
      end

      lead.transition_to!(
        "routed",
        reason: "routing_completed",
        metadata: {
          "processor" => self.class.name,
          "recipient_codes" => recipients.map(&:code),
          "delivery_ids" => deliveries.map(&:id)
        }
      )

      Routing::Result.new(lead, recipients, deliveries, nil)
    end

    def mark_unroutable
      reason = "no_active_recipient_accepts_state"

      lead.transition_to!(
        "unroutable",
        reason: reason,
        metadata: {
          "processor" => self.class.name,
          "accident_state" => lead.accident_state
        }
      )

      Routing::Result.new(lead, [], [], reason)
    end

    def empty_result
      Routing::Result.new(lead, [], [], "lead_not_qualified")
    end
  end
end
