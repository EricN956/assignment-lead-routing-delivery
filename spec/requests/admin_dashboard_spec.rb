require "rails_helper"

RSpec.describe "Admin dashboard", type: :request do
  let(:admin_user) do
    AdminUser.create!(
      email: "dashboard-admin@example.com",
      password: "password",
      password_confirmation: "password"
    )
  end

  before do
    sign_in admin_user
  end

  def create_lead(source_claim_id:, stage:, accident_state: "TX")
    Lead.create!(
      source_claim_id: source_claim_id,
      publisher: "publisher_alpha",
      first_name: "Jordan",
      last_name: "Carter",
      phone: "5553386115",
      email: "#{source_claim_id.downcase}@example.com",
      accident_state: accident_state,
      incident_date: Date.current,
      lead_type: "accident_case",
      stage: stage
    )
  end

  def create_recipient(code:)
    Recipient.create!(
      code: "#{code}_#{SecureRandom.hex(4)}",
      name: "#{code.titleize} Recipient",
      accepted_states: %w[TX],
      base_url: "http://localhost:3100",
      endpoint_path: "/#{code}",
      auth_type: "none",
      client_class: "Recipients::DashboardClient"
    )
  end

  it "renders the CRM dashboard title and summary panels" do
    create_lead(source_claim_id: "RAV-DASH-VALIDATED", stage: "validated")
    create_lead(source_claim_id: "RAV-DASH-CONVERTED", stage: "converted")

    get "/admin"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Lead Routing CRM Dashboard")
    expect(response.body).to include("Lead Lifecycle Summary")
    expect(response.body).to include("Delivery Status Summary")
    expect(response.body).to include("Recent Leads")
    expect(response.body).to include("RAV-DASH-VALIDATED")
    expect(response.body).to include("RAV-DASH-CONVERTED")
  end

  it "renders recent failed dispatch attempts" do
    lead = create_lead(source_claim_id: "RAV-DASH-FAILED", stage: "failed")
    recipient = create_recipient(code: "apex")
    delivery = LeadDelivery.create!(
      lead: lead,
      recipient: recipient,
      status: "failed",
      attempt_count: 1,
      last_error_code: "validation_failed",
      last_error_message: "Invalid lead"
    )
    DispatchAttempt.create!(
      lead_delivery: delivery,
      attempt_number: 1,
      request_method: "POST",
      request_url: "http://localhost:3100/apex/v2/leads",
      response_status: 422,
      response_body: { "error" => "validation_failed" },
      error_message: "Invalid lead",
      retryable: false
    )

    get "/admin"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Recent Failed Dispatch Attempts")
    expect(response.body).to include("RAV-DASH-FAILED")
    expect(response.body).to include("validation_failed")
    expect(response.body).to include("422")
  end

  it "renders recent conversions and postbacks" do
    lead = create_lead(source_claim_id: "RAV-DASH-CONVERSION", stage: "converted")
    recipient = create_recipient(code: "beacon")
    Conversion.create!(
      lead: lead,
      recipient: recipient,
      source_claim_id: lead.source_claim_id,
      external_id: "BCN123456",
      disposition: "signed",
      occurred_at: Time.zone.parse("2026-06-01T08:16:11Z"),
      signature: "secret-signature",
      idempotency_key: "dashboard:#{lead.source_claim_id}:signed",
      raw_payload: {
        "recipient" => recipient.code,
        "source_claim_id" => lead.source_claim_id,
        "disposition" => "signed"
      }
    )

    get "/admin"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Recent Conversions and Postbacks")
    expect(response.body).to include("RAV-DASH-CONVERSION")
    expect(response.body).to include("BCN123456")
    expect(response.body).to include("signed")
  end
end
