assessment = Rails.configuration.x.assessment
base_url = assessment.fetch(:mock_recipients).fetch(:base_url)
recipient_config = assessment.fetch(:recipients)

recipient_rows = [
  {
    code: "apex",
    name: "Apex Legal Intake",
    active: true,
    priority: 1,
    daily_cap: 50,
    accepted_states: %w[TX FL GA NC OH],
    transport: "http",
    base_url: base_url,
    endpoint_path: recipient_config.fetch(:apex).fetch(:endpoint_path),
    auth_type: "api_key",
    client_class: "Recipients::ApexClient",
    settings: {
      "content_type" => "application/json",
      "auth_header" => recipient_config.fetch(:apex).fetch(:auth_header),
      "api_key" => recipient_config.fetch(:apex).fetch(:api_key),
      "success_status" => 202,
      "external_id_field" => "claim_id"
    }
  },
  {
    code: "beacon",
    name: "Beacon Claims",
    active: true,
    priority: 2,
    daily_cap: 30,
    accepted_states: %w[TX CA NY AZ NV],
    transport: "http",
    base_url: base_url,
    endpoint_path: recipient_config.fetch(:beacon).fetch(:endpoint_path),
    auth_type: "api_key",
    client_class: "Recipients::BeaconClient",
    settings: {
      "content_type" => "application/x-www-form-urlencoded",
      "api_key_field" => recipient_config.fetch(:beacon).fetch(:api_key_field),
      "api_key" => recipient_config.fetch(:beacon).fetch(:api_key),
      "phone_field" => "phone10",
      "case_type" => "auto_accident",
      "success_in_body" => true,
      "external_id_field" => "lead_id"
    }
  },
  {
    code: "citadel",
    name: "Citadel Case Desk",
    active: true,
    priority: 3,
    daily_cap: 20,
    accepted_states: %w[FL GA CA NY],
    transport: "http",
    base_url: base_url,
    endpoint_path: recipient_config.fetch(:citadel).fetch(:endpoint_path),
    auth_type: "bearer_token",
    client_class: "Recipients::CitadelClient",
    settings: {
      "content_type" => "application/json",
      "bearer_token" => recipient_config.fetch(:citadel).fetch(:bearer_token),
      "success_status" => 200,
      "external_id_field" => "external_id"
    }
  }
]

recipient_rows.each do |attributes|
  code = attributes.fetch(:code)
  recipient = Recipient.find_or_initialize_by(code: code)
  recipient.assign_attributes(attributes)
  recipient.save!
end
