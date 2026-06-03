module Leads
  class DncScrubber
    def self.call(lead)
      new(lead).call
    end

    def initialize(lead, client: Dnc::SuppressionClient)
      @lead = lead
      @client = client
    end

    def call
      return lead unless lead.stage == "validated"

      result = client.call(lead.phone)

      if result.blocked?
        lead.transition_to!(
          "suppressed",
          reason: "dnc_blocked",
          metadata: metadata_for(result)
        )
      else
        lead.transition_to!(
          "scrubbed",
          reason: "dnc_clear",
          metadata: metadata_for(result)
        )
      end

      lead
    end

    private

    attr_reader :lead, :client

    def metadata_for(result)
      {
        "provider" => "mock_dnc",
        "phone" => result.phone,
        "blocked" => result.blocked,
        "status" => result.status,
        "response_body" => result.response_body
      }
    end
  end
end
