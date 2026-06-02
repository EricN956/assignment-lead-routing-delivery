module Leads
  class PayloadValidator
    REQUIRED_STRING_FIELDS = %i[
      source_claim_id
      publisher
      first_name
      last_name
      accident_state
      lead_type
    ].freeze

    EMAIL_PATTERN = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

    def self.call(attributes, raw_payload: nil)
      new(attributes, raw_payload: raw_payload).call
    end

    def initialize(attributes, raw_payload: nil)
      @attributes = (attributes || {}).with_indifferent_access
      @raw_payload = (raw_payload || attributes[:raw_payload] || {}).with_indifferent_access
      @result = ValidationResult.valid
    end

    def call
      validate_required_string_fields
      validate_phone
      validate_email
      validate_incident_date
      validate_prequal

      result
    end

    private

    attr_reader :attributes, :raw_payload, :result

    def validate_required_string_fields
      REQUIRED_STRING_FIELDS.each do |field|
        result.add(field, "is required") if attributes[field].blank?
      end
    end

    def validate_phone
      raw_phone = raw_payload[:phone].to_s.strip

      if raw_phone.blank?
        result.add(:phone, "is required")
      elsif attributes[:phone].blank?
        result.add(:phone, "must normalize to 10 digits")
      end
    end

    def validate_email
      raw_email = raw_payload[:email].to_s.strip

      if raw_email.blank?
        result.add(:email, "is required")
      elsif attributes[:email].blank? || !attributes[:email].match?(EMAIL_PATTERN)
        result.add(:email, "must be a valid email")
      end
    end

    def validate_incident_date
      raw_incident_date = raw_payload[:incident_date].to_s.strip

      if raw_incident_date.blank?
        result.add(:incident_date, "is required")
      elsif attributes[:incident_date].blank?
        result.add(:incident_date, "must be a valid ISO8601 date")
      end
    end

    def validate_prequal
      unless raw_payload.key?(:prequal)
        result.add(:prequal, "is required")
        return
      end

      result.add(:prequal, "must be an object") unless raw_payload[:prequal].is_a?(Hash)
    end
  end
end
