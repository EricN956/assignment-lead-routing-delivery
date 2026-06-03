require "time"

module Recipients
  class BaseClient
    FILTERED_VALUE = "[FILTERED]"
    SENSITIVE_KEYS = %w[
      authorization
      x-api-key
      api-key
      api_key
      bearer_token
      token
      key
      password
      secret
    ].freeze

    attr_reader :recipient, :http_client, :config

    def initialize(recipient:, http_client: nil, config: Rails.configuration.x.assessment)
      @recipient = recipient
      @config = config
      @http_client = http_client || default_http_client
    end

    def deliver(_lead)
      raise NotImplementedError, "#{self.class.name} must implement #deliver"
    end

    def endpoint_url
      recipient.endpoint_url
    end

    def recipient_code
      recipient.code
    end

    def redacted_hash(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, raw), memo|
          memo[key.to_s] = sensitive_key?(key) ? FILTERED_VALUE : redacted_hash(raw)
        end
      when Array
        value.map { |item| redacted_hash(item) }
      else
        value
      end
    end

    def compact_payload(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, raw), memo|
          compacted = compact_payload(raw)
          next if compacted.nil?
          next if compacted.respond_to?(:empty?) && compacted.empty?

          memo[key] = compacted
        end
      when Array
        value.map { |item| compact_payload(item) }.compact
      else
        value
      end
    end

    def retry_after_seconds(headers)
      value = header_value(headers, "retry-after")
      return nil if value.blank?

      Integer(value)
    rescue ArgumentError
      seconds_until(Time.httpdate(value))
    rescue ArgumentError
      nil
    end

    def request_snapshot(method:, url:, headers:, body:)
      {
        "method" => method.to_s.upcase,
        "url" => url,
        "headers" => redacted_hash(headers),
        "body" => redacted_hash(body)
      }
    end

    def response_snapshot(response)
      {
        "status" => response.status,
        "headers" => redacted_hash(response.headers),
        "body" => response.body,
        "raw_body" => response.raw_body
      }
    end

    private

    def default_http_client
      dispatch_config = config.fetch(:dispatch)

      Integrations::JsonHttpClient.new(
        open_timeout: dispatch_config.fetch(:open_timeout_seconds),
        read_timeout: dispatch_config.fetch(:read_timeout_seconds)
      )
    end

    def sensitive_key?(key)
      SENSITIVE_KEYS.include?(key.to_s.downcase)
    end

    def header_value(headers, name)
      headers.to_h.find { |key, _value| key.to_s.downcase == name }&.last
    end

    def seconds_until(time)
      [(time - Time.current).ceil, 0].max
    end
  end
end
