require "digest"

module Postbacks
  class ConversionRecorder
    Result = Data.define(:conversion, :created, :lead, :recipient) do
      def created?
        created == true
      end

      def duplicate?
        !created?
      end
    end

    def self.call(lead:, recipient:, payload:)
      new(lead: lead, recipient: recipient, payload: payload).call
    end

    def initialize(lead:, recipient:, payload:)
      @lead = lead
      @recipient = recipient
      @payload = payload.to_h.deep_stringify_keys
    end

    def call
      conversion = nil
      created = false

      ActiveRecord::Base.transaction do
        conversion = Conversion.find_or_initialize_by(idempotency_key: idempotency_key)

        if conversion.new_record?
          conversion.assign_attributes(conversion_attributes)
          conversion.save!
          created = true

          update_delivery!(conversion)
          update_lead_stage!(conversion)
          record_conversion_event!(conversion)
        else
          record_duplicate_event!(conversion)
        end
      end

      Result.new(conversion, created, lead, recipient)
    end

    private

    attr_reader :lead, :recipient, :payload

    def conversion_attributes
      {
        lead: lead,
        recipient: recipient,
        source_claim_id: payload.fetch("source_claim_id"),
        external_id: payload.fetch("external_id"),
        disposition: payload.fetch("disposition"),
        occurred_at: parsed_occurred_at,
        signature: payload.fetch("signature"),
        raw_payload: payload
      }
    end

    def idempotency_key
      Digest::SHA256.hexdigest(
        [
          recipient.code,
          payload.fetch("source_claim_id"),
          payload.fetch("external_id"),
          payload.fetch("disposition"),
          payload.fetch("occurred_at"),
          payload.fetch("signature")
        ].join("|")
      )
    end

    def parsed_occurred_at
      Time.zone.parse(payload.fetch("occurred_at").to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def update_delivery!(conversion)
      delivery = LeadDelivery.find_by(lead: lead, recipient: recipient)
      return unless delivery

      delivery.external_id = conversion.external_id if conversion.external_id.present?
      delivery.metadata = delivery.metadata.merge(
        "latest_postback_disposition" => conversion.disposition,
        "latest_postback_at" => conversion.occurred_at&.iso8601,
        "latest_conversion_id" => conversion.id
      )
      delivery.save!
    end

    def update_lead_stage!(conversion)
      case conversion.disposition
      when "signed"
        transition_to_converted!(conversion)
      when "rejected", "not_qualified"
        transition_to_rejected_if_final!(conversion)
      end
    end

    def transition_to_converted!(conversion)
      return if lead.stage == "converted"

      lead.transition_to!(
        "converted",
        reason: "recipient_conversion_signed",
        metadata: event_metadata(conversion)
      )
    end

    def transition_to_rejected_if_final!(conversion)
      return if lead.stage == "converted"
      return if lead.conversions.where(disposition: "signed").where.not(id: conversion.id).exists?
      return unless rejectable_lead_stage?

      lead.transition_to!(
        "rejected",
        reason: "recipient_conversion_rejected",
        metadata: event_metadata(conversion)
      )
    end

    def rejectable_lead_stage?
      %w[delivered dispatched routed failed].include?(lead.stage)
    end

    def record_conversion_event!(conversion)
      lead.record_stage_event!(
        reason: "conversion_recorded",
        metadata: event_metadata(conversion)
      )
    end

    def record_duplicate_event!(conversion)
      lead.record_stage_event!(
        reason: "duplicate_postback_ignored",
        metadata: event_metadata(conversion).merge(
          "idempotency_key" => conversion.idempotency_key
        )
      )
    end

    def event_metadata(conversion)
      {
        "recipient" => recipient.code,
        "source_claim_id" => conversion.source_claim_id,
        "external_id" => conversion.external_id,
        "disposition" => conversion.disposition,
        "occurred_at" => conversion.occurred_at&.iso8601,
        "conversion_id" => conversion.id
      }
    end
  end
end
