module Recipients
  class DeliveryResult
    STATUSES = %w[
      accepted
      duplicate_accepted
      retryable_failure
      rejected_failure
    ].freeze

    attr_reader :status,
                :external_id,
                :error_code,
                :error_message,
                :retry_after_seconds,
                :request,
                :response,
                :metadata

    def self.accepted(external_id:, request:, response:, metadata: {})
      new(
        status: "accepted",
        external_id: external_id,
        request: request,
        response: response,
        metadata: metadata
      )
    end

    def self.duplicate_accepted(external_id:, request:, response:, metadata: {})
      new(
        status: "duplicate_accepted",
        external_id: external_id,
        request: request,
        response: response,
        metadata: metadata
      )
    end

    def self.retryable_failure(error_code:, error_message:, request:, response:, retry_after_seconds: nil, metadata: {})
      new(
        status: "retryable_failure",
        error_code: error_code,
        error_message: error_message,
        request: request,
        response: response,
        retry_after_seconds: retry_after_seconds,
        metadata: metadata
      )
    end

    def self.rejected_failure(error_code:, error_message:, request:, response:, metadata: {})
      new(
        status: "rejected_failure",
        error_code: error_code,
        error_message: error_message,
        request: request,
        response: response,
        metadata: metadata
      )
    end

    def initialize(status:, request:, response:, external_id: nil, error_code: nil, error_message: nil, retry_after_seconds: nil, metadata: {})
      @status = status.to_s
      @external_id = external_id
      @error_code = error_code
      @error_message = error_message
      @retry_after_seconds = retry_after_seconds
      @request = request || {}
      @response = response || {}
      @metadata = metadata || {}

      validate!
    end

    def accepted?
      status == "accepted"
    end

    def duplicate_accepted?
      status == "duplicate_accepted"
    end

    def successful?
      accepted? || duplicate_accepted?
    end

    def retryable?
      status == "retryable_failure"
    end

    def permanent_failure?
      status == "rejected_failure"
    end

    def failed?
      retryable? || permanent_failure?
    end

    def delivery_status
      case status
      when "accepted"
        "delivered"
      when "duplicate_accepted"
        "duplicate_accepted"
      when "retryable_failure"
        "retrying"
      when "rejected_failure"
        "failed"
      else
        raise InvalidDeliveryResult, "Unsupported delivery result status: #{status}"
      end
    end

    def to_h
      {
        "status" => status,
        "delivery_status" => delivery_status,
        "external_id" => external_id,
        "error_code" => error_code,
        "error_message" => error_message,
        "retry_after_seconds" => retry_after_seconds,
        "request" => request,
        "response" => response,
        "metadata" => metadata
      }
    end

    private

    def validate!
      raise InvalidDeliveryResult, "Unsupported status: #{status}" unless STATUSES.include?(status)
      raise InvalidDeliveryResult, "request must be a Hash" unless request.is_a?(Hash)
      raise InvalidDeliveryResult, "response must be a Hash" unless response.is_a?(Hash)
      raise InvalidDeliveryResult, "metadata must be a Hash" unless metadata.is_a?(Hash)
    end
  end
end
