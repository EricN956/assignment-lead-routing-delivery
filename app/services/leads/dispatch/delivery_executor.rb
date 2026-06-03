module Leads
  module Dispatch
    class DeliveryExecutor
      DEFAULT_RETRY_DELAY_SECONDS = 60

      def self.call(lead_delivery)
        new(lead_delivery).call
      end

      def initialize(
        lead_delivery,
        client_registry: Recipients::ClientRegistry,
        job_class: DispatchLeadDeliveryJob,
        config: Rails.configuration.x.assessment
      )
        @lead_delivery = lead_delivery
        @client_registry = client_registry
        @job_class = job_class
        @config = config
      end

      def call
        return lead_delivery if lead_delivery.final?

        mark_lead_dispatched
        execute_delivery
        rollup_lead_status

        lead_delivery
      end

      private

      attr_reader :lead_delivery, :client_registry, :job_class, :config

      delegate :lead, :recipient, to: :lead_delivery

      def execute_delivery
        result = client_registry.build(recipient).deliver(lead)

        ActiveRecord::Base.transaction do
          record_attempt!(result)
          apply_result!(result)
        end
      rescue StandardError => e
        ActiveRecord::Base.transaction do
          record_exception_attempt!(e)
          apply_exception!(e)
        end
      end

      def record_attempt!(result)
        DispatchAttempt.create!(
          lead_delivery: lead_delivery,
          attempt_number: next_attempt_number,
          request_method: result.request.fetch("method", "POST"),
          request_url: result.request.fetch("url", recipient.endpoint_url),
          request_headers: result.request.fetch("headers", {}),
          request_body: result.request.fetch("body", {}),
          response_status: result.response["status"],
          response_headers: result.response.fetch("headers", {}),
          response_body: result.response.fetch("body", {}),
          error_class: nil,
          error_message: result.error_message,
          retryable: result.retryable?
        )
      end

      def record_exception_attempt!(error)
        DispatchAttempt.create!(
          lead_delivery: lead_delivery,
          attempt_number: next_attempt_number,
          request_method: "POST",
          request_url: recipient.endpoint_url,
          request_headers: {},
          request_body: {},
          response_status: nil,
          response_headers: {},
          response_body: {},
          error_class: error.class.name,
          error_message: error.message,
          retryable: can_retry_after_current_attempt?
        )
      end

      def apply_result!(result)
        lead_delivery.attempt_count = current_attempt_number
        lead_delivery.external_id = result.external_id if result.external_id.present?
        lead_delivery.last_error_code = result.error_code
        lead_delivery.last_error_message = result.error_message
        lead_delivery.metadata = result.metadata || {}

        if result.successful?
          mark_successful_delivery!(result)
        elsif result.retryable? && can_retry_after_current_attempt?
          mark_retrying_delivery!(result)
        elsif result.retryable?
          mark_exhausted_delivery!(result)
        else
          mark_failed_delivery!(result)
        end

        lead_delivery.save!
      end

      def apply_exception!(error)
        lead_delivery.attempt_count = current_attempt_number
        lead_delivery.external_id = nil
        lead_delivery.last_error_code = error.class.name
        lead_delivery.last_error_message = error.message
        lead_delivery.metadata = {
          "exception" => true,
          "recipient" => recipient.code
        }

        if can_retry_after_current_attempt?
          lead_delivery.status = "retrying"
          lead_delivery.next_retry_at = Time.current + DEFAULT_RETRY_DELAY_SECONDS.seconds
          enqueue_retry(DEFAULT_RETRY_DELAY_SECONDS)
        else
          lead_delivery.status = "failed"
          lead_delivery.next_retry_at = nil
        end

        lead_delivery.save!
      end

      def mark_successful_delivery!(result)
        lead_delivery.status = result.delivery_status
        lead_delivery.delivered_at ||= Time.current
        lead_delivery.next_retry_at = nil
      end

      def mark_retrying_delivery!(result)
        retry_delay = result.retry_after_seconds.presence || DEFAULT_RETRY_DELAY_SECONDS

        lead_delivery.status = "retrying"
        lead_delivery.next_retry_at = Time.current + retry_delay.seconds

        enqueue_retry(retry_delay)
      end

      def mark_exhausted_delivery!(result)
        lead_delivery.status = "failed"
        lead_delivery.next_retry_at = nil
        lead_delivery.last_error_code = result.error_code || "max_attempts_exhausted"
        lead_delivery.last_error_message = "Retry attempts exhausted"
      end

      def mark_failed_delivery!(result)
        lead_delivery.status = result.delivery_status
        lead_delivery.next_retry_at = nil
      end

      def enqueue_retry(delay_seconds)
        job_class.set(wait: delay_seconds.seconds).perform_later(lead_delivery.id)
      end

      def mark_lead_dispatched
        return unless lead.stage == "routed"

        lead.transition_to!(
          "dispatched",
          reason: "dispatch_started",
          metadata: {
            "delivery_id" => lead_delivery.id,
            "recipient_code" => recipient.code
          }
        )
      end

      def rollup_lead_status
        lead.reload

        if any_successful_delivery?
          mark_lead_delivered
        elsif all_deliveries_final?
          mark_lead_failed
        end
      end

      def mark_lead_delivered
        return unless %w[routed dispatched].include?(lead.stage)

        lead.transition_to!(
          "delivered",
          reason: "dispatch_delivery_succeeded",
          metadata: {
            "successful_delivery_ids" => lead.lead_deliveries.successful.pluck(:id)
          }
        )
      end

      def mark_lead_failed
        return unless %w[routed dispatched].include?(lead.stage)

        lead.transition_to!(
          "failed",
          reason: "all_dispatch_deliveries_failed",
          metadata: {
            "delivery_ids" => lead.lead_deliveries.pluck(:id)
          }
        )
      end

      def any_successful_delivery?
        lead.lead_deliveries.successful.exists?
      end

      def all_deliveries_final?
        lead.lead_deliveries.exists? && lead.lead_deliveries.all?(&:final?)
      end

      def next_attempt_number
        @next_attempt_number ||= lead_delivery.dispatch_attempts.maximum(:attempt_number).to_i + 1
      end

      def current_attempt_number
        next_attempt_number
      end

      def can_retry_after_current_attempt?
        current_attempt_number < max_attempts
      end

      def max_attempts
        config.fetch(:dispatch).fetch(:max_attempts).to_i
      end
    end
  end
end
