require "digest"

module Postbacks
  class SignatureVerifier
    def self.call(payload)
      new(payload).valid?
    end

    def initialize(payload, secret: Rails.configuration.x.assessment.fetch(:postbacks).fetch(:shared_secret))
      @payload = payload.to_h.deep_stringify_keys
      @secret = secret.to_s
    end

    def valid?
      return false if supplied_signature.blank?
      return false if source_claim_id.blank?
      return false if disposition.blank?

      secure_compare(expected_signature, supplied_signature)
    end

    def expected_signature
      Digest::SHA256.hexdigest("#{source_claim_id}:#{disposition}:#{secret}")
    end

    private

    attr_reader :payload, :secret

    def source_claim_id
      payload["source_claim_id"].to_s
    end

    def disposition
      payload["disposition"].to_s
    end

    def supplied_signature
      payload["signature"].to_s
    end

    def secure_compare(expected, supplied)
      return false unless expected.bytesize == supplied.bytesize

      ActiveSupport::SecurityUtils.secure_compare(expected, supplied)
    end
  end
end
