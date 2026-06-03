require "net/http"
require "json"

module Integrations
  class JsonHttpClient
    Response = Data.define(:status, :headers, :body, :raw_body) do
      def success?
        status.between?(200, 299)
      end
    end

    def initialize(open_timeout:, read_timeout:)
      @open_timeout = open_timeout
      @read_timeout = read_timeout
    end

    def post_json(url:, payload:, headers: {})
      uri = URI.parse(url)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      headers.each { |key, value| request[key] = value }
      request.body = JSON.generate(payload)

      execute(uri, request)
    end

    def post_form(url:, payload:, headers: {})
      uri = URI.parse(url)
      request = Net::HTTP::Post.new(uri)
      headers.each { |key, value| request[key] = value }
      request.set_form_data(payload)

      execute(uri, request)
    end

    private

    attr_reader :open_timeout, :read_timeout

    def execute(uri, request)
      response = Net::HTTP.start(
        uri.hostname,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: open_timeout,
        read_timeout: read_timeout
      ) do |http|
        http.request(request)
      end

      Response.new(
        status: response.code.to_i,
        headers: response.to_hash.transform_values { |values| values.join(", ") },
        body: parse_json(response.body),
        raw_body: response.body.to_s
      )
    end

    def parse_json(raw_body)
      JSON.parse(raw_body.to_s)
    rescue JSON::ParserError
      {}
    end
  end
end
