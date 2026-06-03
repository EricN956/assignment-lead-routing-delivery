module Recipients
  class ApexClient < BaseClient
    API_KEY_HEADER = "X-Api-Key"

    def deliver(lead)
      payload = build_payload(lead)
      headers = build_headers

      request = request_snapshot(
        method: "POST",
        url: endpoint_url,
        headers: headers,
        body: payload
      )

      response = http_client.post_json(
        url: endpoint_url,
        payload: payload,
        headers: headers
      )

      response_data = response_snapshot(response)

      build_result(response, request, response_data)
    end

    private

    def build_payload(lead)
      compact_payload(
        {
          source_claim_id: lead.source_claim_id,
          claim: {
            first_name: lead.first_name,
            last_name: lead.last_name,
            phone: lead.phone,
            email: lead.email
          },
          incident: {
            state: lead.accident_state,
            date: lead.incident_date&.iso8601,
            injuries: lead.injuries
          }
        }
      )
    end

    def build_headers
      {
        API_KEY_HEADER => recipient.settings.fetch("api_key")
      }
    end

    def build_result(response, request, response_data)
      case response.status
      when 202
        accepted_result(response, request, response_data)
      when 503
        retryable_result(response, request, response_data)
      else
        failure_result(response, request, response_data)
      end
    end

    def accepted_result(response, request, response_data)
      external_id = response.body["claim_id"]

      DeliveryResult.accepted(
        external_id: external_id,
        request: request,
        response: response_data,
        metadata: {
          "recipient" => recipient.code,
          "status" => response.body["status"]
        }
      )
    end

    def retryable_result(response, request, response_data)
      DeliveryResult.retryable_failure(
        error_code: response.body["error"] || "apex_retryable_failure",
        error_message: "Apex request can be retried",
        retry_after_seconds: retry_after_seconds(response.headers),
        request: request,
        response: response_data,
        metadata: {
          "recipient" => recipient.code
        }
      )
    end

    def failure_result(response, request, response_data)
      DeliveryResult.rejected_failure(
        error_code: response.body["error"] || "apex_rejected_failure",
        error_message: error_message_for(response),
        request: request,
        response: response_data,
        metadata: {
          "recipient" => recipient.code,
          "missing" => response.body["missing"]
        }
      )
    end

    def error_message_for(response)
      case response.status
      when 401
        "Apex authentication failed"
      when 422
        "Apex validation failed"
      else
        "Apex request failed with HTTP #{response.status}"
      end
    end
  end
end
