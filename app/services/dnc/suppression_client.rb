module Dnc
  class SuppressionClient
    Result = Data.define(:phone, :blocked, :status, :response_body) do
      def blocked?
        blocked == true
      end
    end

    class Error < StandardError; end

    def self.call(phone)
      new.call(phone)
    end

    def initialize(
      config: Rails.configuration.x.assessment,
      http_client: default_http_client
    )
      @config = config
      @http_client = http_client
    end

    def call(phone)
      normalized_phone = Leads::PhoneNormalizer.call(phone)

      raise Error, "DNC phone must normalize to 10 digits" if normalized_phone.blank?

      response = http_client.post_json(
        url: endpoint_url,
        payload: { phone: normalized_phone }
      )

      unless response.success?
        raise Error, "DNC request failed with HTTP #{response.status}"
      end

      Result.new(
        phone: response.body.fetch("phone", normalized_phone),
        blocked: response.body.fetch("blocked", false),
        status: response.status,
        response_body: response.body
      )
    rescue KeyError => e
      raise Error, "DNC response missing field: #{e.message}"
    end

    private

    attr_reader :config, :http_client

    def endpoint_url
      base_url = config.fetch(:mock_recipients).fetch(:base_url).to_s.delete_suffix("/")
      path = config.fetch(:dnc).fetch(:endpoint_path).to_s
      path = "/#{path}" unless path.start_with?("/")

      "#{base_url}#{path}"
    end

    def default_http_client
      dispatch_config = Rails.configuration.x.assessment.fetch(:dispatch)

      Integrations::JsonHttpClient.new(
        open_timeout: dispatch_config.fetch(:open_timeout_seconds),
        read_timeout: dispatch_config.fetch(:read_timeout_seconds)
      )
    end
  end
end
