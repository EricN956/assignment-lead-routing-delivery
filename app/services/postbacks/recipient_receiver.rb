module Postbacks
  class RecipientReceiver
    REQUIRED_FIELDS = %w[
      recipient
      source_claim_id
      external_id
      disposition
      occurred_at
      signature
    ].freeze

    VALID_DISPOSITIONS = %w[
      signed
      rejected
      not_qualified
    ].freeze

    Result = Data.define(:status, :http_status, :message, :errors, :lead, :recipient, :payload) do
      def accepted?
        status == "accepted"
      end

      def ignored?
        status == "ignored"
      end

      def invalid?
        status == "invalid" || status == "invalid_signature"
      end

      def invalid_signature?
        status == "invalid_signature"
      end
    end

    def self.call(payload)
      new(payload).call
    end

    def initialize(payload, signature_verifier: SignatureVerifier)
      @payload = normalize_payload(payload)
      @signature_verifier = signature_verifier
    end

    def call
      errors = validation_errors
      return invalid_result(errors) if errors.any?
      return invalid_signature_result unless signature_verifier.call(payload)

      lead = Lead.find_by(source_claim_id: payload.fetch("source_claim_id"))
      recipient = Recipient.find_by(code: payload.fetch("recipient"))

      return ignored_result("unknown_source_claim_id", lead, recipient) unless lead
      return ignored_result("unknown_recipient", lead, recipient) unless recipient

      record_postback_event!(lead, recipient)
      ConversionRecorder.call(lead: lead, recipient: recipient, payload: payload)

      Result.new(
        "accepted",
        :accepted,
        "postback accepted",
        {},
        lead,
        recipient,
        payload
      )
    end

    private

    attr_reader :payload, :signature_verifier

    def normalize_payload(raw_payload)
      source =
        if defined?(ActionController::Parameters) && raw_payload.is_a?(ActionController::Parameters)
          raw_payload.to_unsafe_h
        else
          raw_payload.to_h
        end

      source.deep_stringify_keys
    rescue NoMethodError
      {}
    end

    def validation_errors
      errors = {}

      REQUIRED_FIELDS.each do |field|
        errors[field] = ["is required"] if payload[field].blank?
      end

      if payload["disposition"].present? && VALID_DISPOSITIONS.exclude?(payload["disposition"])
        errors["disposition"] ||= []
        errors["disposition"] << "is not supported"
      end

      if payload["occurred_at"].present? && parsed_occurred_at.blank?
        errors["occurred_at"] ||= []
        errors["occurred_at"] << "must be a valid timestamp"
      end

      errors
    end

    def record_postback_event!(lead, recipient)
      lead.record_stage_event!(
        reason: "recipient_postback_received",
        metadata: {
          "recipient" => recipient.code,
          "source_claim_id" => payload.fetch("source_claim_id"),
          "external_id" => payload.fetch("external_id"),
          "disposition" => payload.fetch("disposition"),
          "occurred_at" => payload.fetch("occurred_at"),
          "signature_present" => payload["signature"].present?,
          "signature_verified" => true
        }
      )
    end

    def invalid_result(errors)
      Result.new(
        "invalid",
        :unprocessable_entity,
        "postback payload invalid",
        errors,
        nil,
        nil,
        payload
      )
    end

    def invalid_signature_result
      Result.new(
        "invalid_signature",
        :unauthorized,
        "postback signature invalid",
        { "signature" => ["is invalid"] },
        nil,
        nil,
        payload
      )
    end

    def ignored_result(message, lead, recipient)
      Result.new(
        "ignored",
        :accepted,
        message,
        {},
        lead,
        recipient,
        payload
      )
    end

    def parsed_occurred_at
      @parsed_occurred_at ||= Time.zone.parse(payload["occurred_at"].to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
