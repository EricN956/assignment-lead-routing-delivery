require "rails_helper"

RSpec.describe "Admin lead show", type: :request do
  let(:admin_user) do
    AdminUser.create!(
      email: "lead-show-admin@example.com",
      password: "password",
      password_confirmation: "password"
    )
  end

  before do
    sign_in admin_user
  end

  def create_lead
    Lead.create!(
      source_claim_id: "RAV-SHOW-1",
      publisher: "publisher_alpha",
      first_name: "Jordan",
      last_name: "Carter",
      phone: "5553386115",
      email: "jordan.show@example.com",
      accident_state: "TX",
      incident_date: Date.iso8601("2026-04-02"),
      injuries: "neck and back pain",
      lead_type: "accident_case",
      stage: "invalid",
      invalid_reason: "email",
      validation_errors: {
        "email" => ["is required"]
      },
      disqualification_reasons: [
        {
          "code" => "not_at_fault",
          "message" => "Lead must indicate claimant was not at fault"
        }
      ],
      prequal: {
        "has_injuries" => true,
        "not_at_fault" => false
      },
      raw_payload: {
        "source_claim_id" => "RAV-SHOW-1",
        "email" => ""
      }
    )
  end

  def create_recipient(code:)
    Recipient.create!(
      code: code,
      name: "#{code.titleize} Recipient",
      accepted_states: %w[TX],
      base_url: "http://localhost:3100",
      endpoint_path: "/#{code}",
      auth_type: "none",
      client_class: "Recipients::AdminShowClient"
    )
  end

  it "renders the lead summary and contact details" do
    lead = create_lead

    get "/admin/leads/#{lead.id}"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Lead RAV-SHOW-1")
    expect(response.body).to include("Lead Summary")
    expect(response.body).to include("Contact and Incident")
    expect(response.body).to include("Jordan Carter")
    expect(response.body).to include("5553386115")
    expect(response.body).to include("jordan.show@example.com")
  end

  it "renders validation, qualification, and raw payload details" do
    lead = create_lead

    get "/admin/leads/#{lead.id}"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Validation and Qualification")
    expect(response.body).to include("is required")
    expect(response.body).to include("not_at_fault")
    expect(response.body).to include("has_injuries")
    expect(response.body).to include("Raw Payload")
  end

  it "renders lifecycle timeline events in order" do
    lead = create_lead
    lead.record_stage_event!(
      reason: "ingest_validation_failed",
      metadata: {
        "errors" => {
          "email" => ["is required"]
        }
      }
    )

    get "/admin/leads/#{lead.id}"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Lifecycle Timeline")
    expect(response.body).to include("lead_received")
    expect(response.body).to include("ingest_validation_failed")
    expect(response.body).to include("invalid")
  end

  it "renders recipient delivery and dispatch attempt details" do
    lead = create_lead
    recipient = create_recipient(code: "apex")
    delivery = LeadDelivery.create!(
      lead: lead,
      recipient: recipient,
      status: "retrying",
      external_id: "APX-123",
      attempt_count: 1,
      next_retry_at: 5.minutes.from_now,
      last_error_code: "upstream_unavailable",
      last_error_message: "Apex request can be retried",
      metadata: {
        "latest_status" => "retrying"
      }
    )
    DispatchAttempt.create!(
      lead_delivery: delivery,
      attempt_number: 1,
      request_method: "POST",
      request_url: "http://localhost:3100/apex/v2/leads",
      request_body: {
        "source_claim_id" => "RAV-SHOW-1"
      },
      response_status: 503,
      response_body: {
        "error" => "upstream_unavailable"
      },
      retryable: true
    )

    get "/admin/leads/#{lead.id}"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Recipient Deliveries")
    expect(response.body).to include("Dispatch Attempts")
    expect(response.body).to include("apex")
    expect(response.body).to include("retrying")
    expect(response.body).to include("APX-123")
    expect(response.body).to include("upstream_unavailable")
    expect(response.body).to include("http://localhost:3100/apex/v2/leads")
  end

  it "renders conversion and postback details" do
    lead = create_lead
    recipient = create_recipient(code: "beacon")
    Conversion.create!(
      lead: lead,
      recipient: recipient,
      source_claim_id: lead.source_claim_id,
      external_id: "BCN123456",
      disposition: "signed",
      occurred_at: Time.zone.parse("2026-06-01T08:16:11Z"),
      signature: "secret-signature",
      idempotency_key: "beacon:RAV-SHOW-1:BCN123456:signed",
      raw_payload: {
        "recipient" => "beacon",
        "source_claim_id" => "RAV-SHOW-1",
        "disposition" => "signed"
      }
    )

    get "/admin/leads/#{lead.id}"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Conversions and Postbacks")
    expect(response.body).to include("beacon")
    expect(response.body).to include("BCN123456")
    expect(response.body).to include("signed")
    expect(response.body).to include("[FILTERED]")
  end
end
