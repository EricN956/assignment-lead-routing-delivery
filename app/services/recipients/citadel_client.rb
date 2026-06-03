module Recipients
  class CitadelClient < BaseClient
    AUTHORIZATION_HEADER = "Authorization"

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
          first_name: lead.first_name,
          last_name: lead.last_name,
          phone: lead.phone,
          email: lead.email,
          accident_state: lead.accident_state,
          injuries: lead.injuries
        }
      )
    end

    def build_headers
      {
        AUTHORIZATION_HEADER => "Bearer #{recipient.settings.fetch("bearer_token")}"
      }
    end

    def build_result(response, request, response_data)
      case response.status
      when 200
        accepted_or_rejected_result(response, request, response_data)
      when 409
        duplicate_result(response, request, response_data)
      when 429
        retryable_result(response, request, response_data)
      when 500..599
        retryable_result(response, request, response_data)
      else
        failure_result(response, request, response_data)
      end
    end

    def accepted_or_rejected_result(response, request, response_data)
      if response.body["accepted"] == true
        DeliveryResult.accepted(
          external_id: response.body["external_id"],
          request: request,
          response: response_data,
          metadata: {
            "recipient" => recipient.code,
            "accepted" => true
          }
        )
      else
        DeliveryResult.rejected_failure(
          error_code: response.body["error"] || "citadel_not_accepted",
          error_message: "Citadel did not accept the lead",
          request: request,
          response: response_data,
          metadata: {
            "recipient" => recipient.code,
            "accepted" => response.body["accepted"]
          }
        )
      end
    end

    def duplicate_result(response, request, response_data)
      DeliveryResult.duplicate_accepted(
        external_id: response.body["external_id"] || response.body["source_claim_id"],
        request: request,
        response: response_data,
        metadata: {
          "recipient" => recipient.code,
          "error" => "duplicate",
          "source_claim_id" => response.body["source_claim_id"]
        }
      )
    end

    def retryable_result(response, request, response_data)
      DeliveryResult.retryable_failure(
        error_code: response.body["error"] || "citadel_retryable_failure",
        error_message: retryable_message_for(response),
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
        error_code: response.body["error"] || "citadel_rejected_failure",
        error_message: failure_message_for(response),
        request: request,
        response: response_data,
        metadata: {
          "recipient" => recipient.code,
          "missing" => response.body["missing"]
        }
      )
    end

    def retryable_message_for(response)
      case response.status
      when 429
        "Citadel rate limit reached"
      else
        "Citadel request can be retried"
      end
    end

    def failure_message_for(response)
      case response.status
      when 401
        "Citadel authentication failed"
      when 422
        "Citadel validation failed"
      else
        "Citadel request failed with HTTP #{response.status}"
      end
    end
  end
end
