require "rails_helper"

RSpec.describe Leads::Dispatch::DeliveryExecutor do
  class DispatchSpecClientRegistry
    def initialize(result_or_error)
      @result_or_error = result_or_error
    end

    def build(_recipient)
      result_or_error = @result_or_error

      Class.new do
        define_method(:deliver) do |_lead|
          raise result_or_error if result_or_error.is_a?(Exception)

          result_or_error
        end
      end.new
    end
  end

  class DispatchSpecJob
    class << self
      attr_accessor :scheduled_jobs
    end

    self.scheduled_jobs = []

    def self.set(wait:)
      scheduled_jobs << { wait: wait }
      self
    end

    def self.perform_later(lead_delivery_id)
      scheduled_jobs.last[:lead_delivery_id] = lead_delivery_id
    end
  end

  def reset_jobs
    DispatchSpecJob.scheduled_jobs = []
  end

  def create_delivery
    lead = Lead.create!(
      source_claim_id: "RAV-DISPATCH-#{SecureRandom.hex(4)}",
      publisher: "publisher_alpha",
      first_name: "Drew",
      last_name: "Lane",
      phone: "5553386115",
      email: "dispatch@example.com",
      accident_state: "TX",
      incident_date: Date.current,
      lead_type: "accident_case",
      stage: "routed"
    )

    recipient = Recipient.create!(
      code: "dispatch_recipient_#{SecureRandom.hex(4)}",
      name: "Dispatch Recipient",
      accepted_states: %w[TX],
      base_url: "http://localhost:3100",
      endpoint_path: "/dispatch",
      auth_type: "none",
      client_class: "Recipients::DispatchSpecClient"
    )

    LeadDelivery.create!(lead: lead, recipient: recipient)
  end

  def accepted_result
    Recipients::DeliveryResult.accepted(
      external_id: "EXT-123",
      request: {
        "method" => "POST",
        "url" => "http://localhost:3100/dispatch",
        "headers" => {},
        "body" => { "source_claim_id" => "RAV-DISPATCH" }
      },
      response: {
        "status" => 202,
        "headers" => {},
        "body" => { "external_id" => "EXT-123" }
      },
      metadata: { "recipient" => "dispatch_recipient" }
    )
  end

  def retryable_result
    Recipients::DeliveryResult.retryable_failure(
      error_code: "rate_limited",
      error_message: "Retry later",
      retry_after_seconds: 10,
      request: {
        "method" => "POST",
        "url" => "http://localhost:3100/dispatch",
        "headers" => {},
        "body" => {}
      },
      response: {
        "status" => 429,
        "headers" => { "retry-after" => "10" },
        "body" => { "error" => "rate_limited" }
      }
    )
  end

  def failed_result
    Recipients::DeliveryResult.rejected_failure(
      error_code: "validation_failed",
      error_message: "Invalid lead",
      request: {
        "method" => "POST",
        "url" => "http://localhost:3100/dispatch",
        "headers" => {},
        "body" => {}
      },
      response: {
        "status" => 422,
        "headers" => {},
        "body" => { "error" => "validation_failed" }
      }
    )
  end

  before do
    reset_jobs
  end

  it "records successful dispatch attempts and marks lead delivered" do
    delivery = create_delivery

    described_class.new(
      delivery,
      client_registry: DispatchSpecClientRegistry.new(accepted_result),
      job_class: DispatchSpecJob
    ).call

    expect(delivery.reload).to have_attributes(
      status: "delivered",
      external_id: "EXT-123",
      attempt_count: 1
    )
    expect(delivery.delivered_at).to be_present
    expect(delivery.dispatch_attempts.count).to eq(1)
    expect(delivery.dispatch_attempts.first).to have_attributes(
      attempt_number: 1,
      response_status: 202,
      retryable: false
    )
    expect(delivery.lead.reload.stage).to eq("delivered")
    expect(delivery.lead.latest_stage_event.reason).to eq("dispatch_delivery_succeeded")
  end

  it "marks retryable delivery failures and schedules a retry" do
    delivery = create_delivery

    described_class.new(
      delivery,
      client_registry: DispatchSpecClientRegistry.new(retryable_result),
      job_class: DispatchSpecJob
    ).call

    expect(delivery.reload.status).to eq("retrying")
    expect(delivery.attempt_count).to eq(1)
    expect(delivery.next_retry_at).to be_present
    expect(delivery.dispatch_attempts.first).to have_attributes(
      response_status: 429,
      retryable: true
    )
    expect(DispatchSpecJob.scheduled_jobs.last[:lead_delivery_id]).to eq(delivery.id)
  end

  it "marks permanent delivery failures as failed" do
    delivery = create_delivery

    described_class.new(
      delivery,
      client_registry: DispatchSpecClientRegistry.new(failed_result),
      job_class: DispatchSpecJob
    ).call

    expect(delivery.reload.status).to eq("failed")
    expect(delivery.last_error_code).to eq("validation_failed")
    expect(delivery.next_retry_at).to be_nil
    expect(delivery.lead.reload.stage).to eq("failed")
  end

  it "turns retryable results into failed after max attempts are exhausted" do
    delivery = create_delivery
    delivery.update!(attempt_count: 2)

    2.times do |attempt|
      DispatchAttempt.create!(
        lead_delivery: delivery,
        attempt_number: attempt + 1,
        request_method: "POST",
        request_url: "http://localhost:3100/dispatch"
      )
    end

    described_class.new(
      delivery,
      client_registry: DispatchSpecClientRegistry.new(retryable_result),
      job_class: DispatchSpecJob
    ).call

    expect(delivery.reload.status).to eq("failed")
    expect(delivery.attempt_count).to eq(3)
    expect(delivery.last_error_message).to eq("Retry attempts exhausted")
    expect(DispatchSpecJob.scheduled_jobs).to eq([])
  end

  it "records client exceptions as retryable attempts before max attempts" do
    delivery = create_delivery

    described_class.new(
      delivery,
      client_registry: DispatchSpecClientRegistry.new(StandardError.new("network down")),
      job_class: DispatchSpecJob
    ).call

    expect(delivery.reload.status).to eq("retrying")
    expect(delivery.last_error_code).to eq("StandardError")
    expect(delivery.dispatch_attempts.first).to have_attributes(
      error_class: "StandardError",
      error_message: "network down",
      retryable: true
    )
    expect(DispatchSpecJob.scheduled_jobs.last[:lead_delivery_id]).to eq(delivery.id)
  end

  it "does not reprocess final deliveries" do
    delivery = create_delivery
    delivery.update!(status: "delivered", delivered_at: Time.current)

    described_class.new(
      delivery,
      client_registry: DispatchSpecClientRegistry.new(failed_result),
      job_class: DispatchSpecJob
    ).call

    expect(delivery.reload.status).to eq("delivered")
    expect(delivery.dispatch_attempts).to be_empty
  end
end
