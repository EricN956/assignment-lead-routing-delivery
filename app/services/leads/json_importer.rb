require "json"

module Leads
  class JsonImporter
    def self.call(path)
      new(path).call
    end

    def initialize(path)
      @path = Pathname(path.to_s)
      @summary = ImportSummary.new
    end

    def call
      payloads.each do |payload|
        summary.increment_total
        import_payload(payload)
      end

      summary
    end

    private

    attr_reader :path, :summary

    def payloads
      raise ArgumentError, "Lead import file does not exist: #{path}" unless path.exist?

      parsed = JSON.parse(path.read)

      unless parsed.is_a?(Array)
        raise ArgumentError, "Lead import JSON must be an array of lead payloads"
      end

      parsed
    rescue JSON::ParserError => e
      raise ArgumentError, "Lead import JSON is invalid: #{e.message}"
    end

    def import_payload(payload)
      attributes = PayloadNormalizer.call(payload)
      validation_result = PayloadValidator.call(attributes)

      source_claim_id = attributes[:source_claim_id]

      if source_claim_id.present? && Lead.exists?(source_claim_id: source_claim_id)
        summary.record_duplicate
        return
      end

      lead = Lead.create!(lead_attributes(attributes, validation_result))

      if validation_result.valid?
        lead.transition_to!(
          "validated",
          reason: "ingest_validation_passed",
          metadata: { "importer" => self.class.name }
        )
        summary.record_valid
      else
        lead.transition_to!(
          "invalid",
          reason: "ingest_validation_failed",
          metadata: { "errors" => validation_result.to_h }
        )
        summary.record_invalid
      end
    rescue StandardError => e
      summary.record_failure(identifier: payload_identifier(payload), error: e)
      Rails.logger.error("[Leads::JsonImporter] #{payload_identifier(payload)} #{e.class}: #{e.message}")
    end

    def lead_attributes(attributes, validation_result)
      attributes.merge(
        validation_errors: validation_result.to_h,
        invalid_reason: invalid_reason(validation_result)
      )
    end

    def invalid_reason(validation_result)
      return nil if validation_result.valid?

      validation_result.to_h.keys.sort.join(", ")
    end

    def payload_identifier(payload)
      payload.to_h.with_indifferent_access[:source_claim_id].presence || "unknown"
    rescue NoMethodError
      "unknown"
    end
  end
end
