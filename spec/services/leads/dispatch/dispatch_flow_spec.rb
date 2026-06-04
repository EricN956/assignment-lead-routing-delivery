require "rails_helper"

RSpec.describe "Recipient dispatch flow" do
  include ActiveJob::TestHelper

  before do
    Rails.application.load_seed
    clear_enqueued_jobs
    clear_performed_jobs
  end

  after do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  def recipient(code)
    Recipient.find_by!(code: code)
  end

  def create_routed_lead(source_claim_id:, accident_state:)
    Lead.create!(
      source_claim_id: source_claim_id,
      publisher: "publisher_alpha",
      first_name: "Jordan",
      last_name: "Carter",
      phone: "5553386115",
      email: "#{source_claim_id.downcase}@example.com",
      accident_state: accident_state,
      incident_date: Date.iso8601("2026-04-02"),
      injuries: "neck and back pain",
      lead_type: "accident_case",
      stage: "routed",
      prequal: {
        "has_injuries" => true,
        "not_at_fault" => true,
        "within_1_year" => true,
        "has_no_attorney" => true,
        "not_previously_dropped_or_settled" => true,
        "has_received_medical_treatment" => true
      }
    )
  end

  def create_delivery(code:, source_claim_id:, accident_state:)
    lead = create_routed_lead(
      source_claim_id: source_claim_id,
      accident_state: accident_state
    )

    LeadDelivery.create!(
      lead: lead,
      recipient: recipient(code)
    )
  end

  it "dispatches an Apex delivery through the real client registry and records audit data" do
    delivery = create_delivery(
      code: "apex",
      source_claim_id: "RAV-DISPATCH-APEX",
      accident_state: "TX"
    )

    stub_request(:post, "http://localhost:3100/apex/v2/leads")
      .with(headers: { "X-Api-Key" => "apex-test-key-123" })
      .to_return(
        status: 202,
        body: { claim_id: "APX-FLOW-1", status: "accepted" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    Leads::Dispatch::DeliveryExecutor.call(delivery)

    expect(delivery.reload).to have_attributes(
      status: "delivered",
      external_id: "APX-FLOW-1",
      attempt_count: 1
    )
    expect(delivery.lead.reload.stage).to eq("delivered")

    attempt = delivery.dispatch_attempts.first
    expect(attempt).to have_attributes(
      attempt_number: 1,
      request_method: "POST",
      request_url: "http://localhost:3100/apex/v2/leads",
      response_status: 202,
      retryable: false
    )
    expect(attempt.request_headers).to eq("X-Api-Key" => "[FILTERED]")
    expect(attempt.request_body).to include(
      "source_claim_id" => "RAV-DISPATCH-APEX"
    )
    expect(attempt.response_body).to include(
      "claim_id" => "APX-FLOW-1"
    )
  end

  it "dispatches a Beacon delivery using form encoding and records a delivered attempt" do
    delivery = create_delivery(
      code: "beacon",
      source_claim_id: "RAV-DISPATCH-BEACON",
      accident_state: "TX"
    )

    stub_request(:post, "http://localhost:3100/beacon/api/addLead")
      .with(
        body: hash_including(
          "key" => "beacon-test-key-456",
          "source_claim_id" => "RAV-DISPATCH-BEACON",
          "phone10" => "5553386115",
          "case_type" => "auto_accident"
        )
      )
      .to_return(
        status: 200,
        body: { success: 1, lead_id: "BCN-FLOW-1" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    Leads::Dispatch::DeliveryExecutor.call(delivery)

    expect(delivery.reload).to have_attributes(
      status: "delivered",
      external_id: "BCN-FLOW-1",
      attempt_count: 1
    )
    expect(delivery.lead.reload.stage).to eq("delivered")

    attempt = delivery.dispatch_attempts.first
    expect(attempt.response_status).to eq(200)
    expect(attempt.request_body).to include(
      "key" => "[FILTERED]",
      "source_claim_id" => "RAV-DISPATCH-BEACON",
      "phone10" => "5553386115"
    )
    expect(attempt.response_body).to include(
      "lead_id" => "BCN-FLOW-1"
    )
  end

  it "dispatches a Citadel duplicate response as a successful duplicate delivery" do
    delivery = create_delivery(
      code: "citadel",
      source_claim_id: "RAV-DISPATCH-CITADEL-DUP",
      accident_state: "FL"
    )

    stub_request(:post, "http://localhost:3100/citadel/intake")
      .with(headers: { "Authorization" => "Bearer citadel-test-token-789" })
      .to_return(
        status: 409,
        body: {
          error: "duplicate",
          source_claim_id: "RAV-DISPATCH-CITADEL-DUP"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    Leads::Dispatch::DeliveryExecutor.call(delivery)

    expect(delivery.reload).to have_attributes(
      status: "duplicate_accepted",
      external_id: "RAV-DISPATCH-CITADEL-DUP",
      attempt_count: 1
    )
    expect(delivery).to be_successful
    expect(delivery.lead.reload.stage).to eq("delivered")

    attempt = delivery.dispatch_attempts.first
    expect(attempt.request_headers).to eq("Authorization" => "[FILTERED]")
    expect(attempt.response_status).to eq(409)
    expect(attempt.response_body).to include(
      "error" => "duplicate"
    )
  end

  it "records Citadel rate limits as retryable dispatch attempts" do
    delivery = create_delivery(
      code: "citadel",
      source_claim_id: "RAV-DISPATCH-CITADEL-RETRY",
      accident_state: "FL"
    )

    stub_request(:post, "http://localhost:3100/citadel/intake")
      .to_return(
        status: 429,
        body: { error: "rate_limited" }.to_json,
        headers: {
          "Content-Type" => "application/json",
          "Retry-After" => "3"
        }
      )

    Leads::Dispatch::DeliveryExecutor.call(delivery)

    expect(delivery.reload).to have_attributes(
      status: "retrying",
      attempt_count: 1,
      last_error_code: "rate_limited",
      last_error_message: "Citadel rate limit reached"
    )
    expect(delivery.next_retry_at).to be_present
    expect(delivery.lead.reload.stage).to eq("dispatched")

    attempt = delivery.dispatch_attempts.first
    expect(attempt).to have_attributes(
      response_status: 429,
      retryable: true
    )

    expect(enqueued_jobs.size).to eq(1)
    expect(enqueued_jobs.first[:job]).to eq(DispatchLeadDeliveryJob)
  end

  it "records Apex permanent failures and rolls up the lead to failed when all deliveries fail" do
    delivery = create_delivery(
      code: "apex",
      source_claim_id: "RAV-DISPATCH-APEX-FAIL",
      accident_state: "TX"
    )

    stub_request(:post, "http://localhost:3100/apex/v2/leads")
      .to_return(
        status: 422,
        body: {
          error: "validation_failed",
          missing: ["claim.email"]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    Leads::Dispatch::DeliveryExecutor.call(delivery)

    expect(delivery.reload).to have_attributes(
      status: "failed",
      attempt_count: 1,
      last_error_code: "validation_failed",
      last_error_message: "Apex validation failed"
    )
    expect(delivery.next_retry_at).to be_nil
    expect(delivery.lead.reload.stage).to eq("failed")

    attempt = delivery.dispatch_attempts.first
    expect(attempt.response_status).to eq(422)
    expect(attempt.retryable).to be(false)
    expect(attempt.response_body).to include(
      "error" => "validation_failed",
      "missing" => ["claim.email"]
    )
  end
end
