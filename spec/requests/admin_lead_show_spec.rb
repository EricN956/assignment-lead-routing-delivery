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
end
