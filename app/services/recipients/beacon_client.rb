module Recipients
  class BeaconClient < BaseClient
    def deliver(lead)
      payload = build_payload(lead)
      headers = {}

      request = request_snapshot(
        method: "POST",
        url: endpoint_url,
        headers: headers,
        body: payload
      )

      response = http_client.post_form(
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
          "key" => recipient.settings.fetch("api_key"),
          "source_claim_id" => lead.source_claim_id,
          "first_name" => lead.first_name,
          "last_name" => lead.last_name,
          "phone10" => Leads::PhoneNormalizer.call(lead.phone),
          "case_type" => recipient.settings.fetch("case_type", "auto_accident")
        }
      )
    end

    def build_result(response, request, response_data)
      return retryable_http_failure(response, request, response_data) if response.status >= 500
      return rejected_http_failure(response, request, response_data) unless response.status == 200

      if response.body["success"].to_i == 1
        accepted_result(response, request, response_data)
      elsif response.body["error"] == "duplicate"
        duplicate_result(response, request, response_data)
      else
        rejected_body_failure(response, request, response_data)
      end
    end

    def accepted_result(response, request, response_data)
      DeliveryResult.accepted(
        external_id: response.body["lead_id"],
        request: request,
        response: response_data,
        metadata: {
          "recipient" => recipient.code,
          "success" => response.body["success"]
        }
      )
    end

    def duplicate_result(response, request, response_data)
      DeliveryResult.duplicate_accepted(
        external_id: response.body["lead_id"],
        request: request,
        response: response_data,
        metadata: {
          "recipient" => recipient.code,
          "error" => "duplicate"
        }
      )
    end

    def rejected_body_failure(response, request, response_data)
      DeliveryResult.rejected_failure(
        error_code: response.body["error"] || "beacon_rejected_failure",
        error_message: "Beacon rejected the lead",
        request: request,
        response: response_data,
        metadata: {
          "recipient" => recipient.code,
          "success" => response.body["success"]
        }
      )
    end

    def retryable_http_failure(response, request, response_data)
      DeliveryResult.retryable_failure(
        error_code: response.body["error"] || "beacon_retryable_http_failure",
        error_message: "Beacon request can be retried",
        retry_after_seconds: retry_after_seconds(response.headers),
        request: request,
        response: response_data,
        metadata: {
          "recipient" => recipient.code
        }
      )
    end

    def rejected_http_failure(response, request, response_data)
      DeliveryResult.rejected_failure(
        error_code: response.body["error"] || "beacon_http_failure",
        error_message: "Beacon request failed with HTTP #{response.status}",
        request: request,
        response: response_data,
        metadata: {
          "recipient" => recipient.code
        }
      )
    end
  end
end
