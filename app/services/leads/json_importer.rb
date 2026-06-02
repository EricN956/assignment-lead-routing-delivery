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
      if source_claim_id.present?
        existing_lead = Lead.find_by(source_claim_id: source_claim_id)
        return record_duplicate(existing_lead, payload) if existing_lead
      end

      lead = Lead.create!(lead_attributes(attributes, validation_result))

      if validation_result.valid?
        lead.transition_to!(
          "validated",
          reason: "ingest_validation_passed",
          metadata: { "importer" => self.class.name, "path" => relative_path }
        )
        summary.record_valid
      else
        lead.transition_to!(
          "invalid",
          reason: "ingest_validation_failed",
          metadata: { "errors" => validation_result.to_h, "importer" => self.class.name, "path" => relative_path }
        )
        summary.record_invalid
      end
    rescue StandardError => e
      summary.record_failure(identifier: payload_identifier(payload), error: e)
      Rails.logger.error("[Leads::JsonImporter] #{payload_identifier(payload)} #{e.class}: #{e.message}")
    end

    def record_duplicate(existing_lead, payload)
      existing_lead.record_stage_event!(
        reason: "duplicate_import_skipped",
        metadata: {
          "importer" => self.class.name,
          "path" => relative_path,
          "source_claim_id" => existing_lead.source_claim_id,
          "existing_stage" => existing_lead.stage,
          "payload_keys" => payload_keys(payload)
        }
      )

      summary.record_duplicate
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

    def payload_keys(payload)
      payload.to_h.keys.map(&:to_s).sort
    rescue NoMethodError
      []
    end

    def relative_path
      path.relative_path_from(Rails.root).to_s
    rescue ArgumentError
      path.to_s
    end
  end
end
