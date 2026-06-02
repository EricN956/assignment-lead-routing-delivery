module Leads
  class PayloadNormalizer
    def self.call(payload)
      new(payload).call
    end

    def initialize(payload)
      @payload = payload || {}
    end

    def call
      raw = normalized_payload

      {
        source_claim_id: clean_string(raw[:source_claim_id]),
        publisher: clean_string(raw[:publisher]),
        received_at: parse_time(raw[:received_at]),

        first_name: clean_string(raw[:first_name]),
        last_name: clean_string(raw[:last_name]),
        phone: PhoneNormalizer.call(raw[:phone]),
        email: EmailNormalizer.call(raw[:email]),

        address_1: clean_string(raw[:address_1]),
        city: clean_string(raw[:city]),
        state: state_code(raw[:state]),
        postal_code: clean_string(raw[:postal_code]),

        accident_state: state_code(raw[:accident_state]),
        incident_date: parse_date(raw[:incident_date]),
        role: clean_string(raw[:role]),
        injuries: clean_string(raw[:injuries]),
        lead_type: clean_string(raw[:lead_type]),
        test_lead: boolean_value(raw[:test_lead]),
        trustedform_cert_url: clean_string(raw[:trustedform_cert_url]),

        prequal: hash_value(raw[:prequal]),
        raw_payload: raw.to_h.deep_stringify_keys
      }
    end

    private

    attr_reader :payload

    def normalized_payload
      payload.to_h.with_indifferent_access
    rescue NoMethodError
      {}.with_indifferent_access
    end

    def clean_string(value)
      value.to_s.strip.presence
    end

    def state_code(value)
      clean_string(value)&.upcase
    end

    def parse_time(value)
      return nil if clean_string(value).blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def parse_date(value)
      return nil if clean_string(value).blank?

      Date.iso8601(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def boolean_value(value)
      return false if value.nil?

      ActiveModel::Type::Boolean.new.cast(value) || false
    end

    def hash_value(value)
      return value.deep_stringify_keys if value.is_a?(Hash)

      {}
    end
  end
end
