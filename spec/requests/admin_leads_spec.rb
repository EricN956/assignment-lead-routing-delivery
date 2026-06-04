require "rails_helper"

RSpec.describe "Admin leads", type: :request do
  let(:admin_user) do
    AdminUser.create!(
      email: "lead-admin@example.com",
      password: "password",
      password_confirmation: "password"
    )
  end

  before do
    sign_in admin_user
  end

  def create_lead(source_claim_id:, stage:, accident_state: "TX", test_lead: false)
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
      stage: stage,
      test_lead: test_lead
    )
  end

  it "renders the lead CRM index" do
    create_lead(source_claim_id: "RAV-ADMIN-1", stage: "validated")

    get "/admin/leads"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("CRM Leads")
    expect(response.body).to include("RAV-ADMIN-1")
    expect(response.body).to include("validated")
  end

  it "supports filtering by stage" do
    create_lead(source_claim_id: "RAV-ADMIN-VALIDATED", stage: "validated")
    create_lead(source_claim_id: "RAV-ADMIN-INVALID", stage: "invalid")

    get "/admin/leads", params: { q: { stage_eq: "invalid" } }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("RAV-ADMIN-INVALID")
    expect(response.body).not_to include("RAV-ADMIN-VALIDATED")
  end

  it "shows delivery status summaries on the index" do
    lead = create_lead(source_claim_id: "RAV-ADMIN-DELIVERY", stage: "routed")
    recipient = Recipient.create!(
      code: "admin_recipient_#{SecureRandom.hex(4)}",
      name: "Admin Recipient",
      accepted_states: %w[TX],
      base_url: "http://localhost:3100",
      endpoint_path: "/admin",
      auth_type: "none",
      client_class: "Recipients::AdminClient"
    )
    LeadDelivery.create!(
      lead: lead,
      recipient: recipient,
      status: "pending"
    )

    get "/admin/leads"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("RAV-ADMIN-DELIVERY")
    expect(response.body).to include("#{recipient.code}: pending")
  end
end
