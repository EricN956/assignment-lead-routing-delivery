require "rails_helper"

RSpec.describe Dnc::SuppressionClient do
  let(:base_url) { Rails.configuration.x.assessment.fetch(:mock_recipients).fetch(:base_url) }
  let(:endpoint) { "#{base_url}/scrub/dnc" }

  it "returns blocked true for suppressed phone numbers" do
    stub_request(:post, endpoint)
      .with(
        headers: { "Content-Type" => "application/json" },
        body: { phone: "5550000001" }.to_json
      )
      .to_return(
        status: 200,
        body: { phone: "5550000001", blocked: true }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = described_class.call("5550000001")

    expect(result).to be_blocked
    expect(result.phone).to eq("5550000001")
    expect(result.status).to eq(200)
  end

  it "normalizes formatted phone numbers before calling DNC" do
    stub_request(:post, endpoint)
      .with(body: { phone: "5553386115" }.to_json)
      .to_return(
        status: 200,
        body: { phone: "5553386115", blocked: false }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = described_class.call("+1 (555) 338-6115")

    expect(result).not_to be_blocked
    expect(result.phone).to eq("5553386115")
  end

  it "raises a clear error for malformed phone numbers" do
    expect do
      described_class.call("555")
    end.to raise_error(Dnc::SuppressionClient::Error, /normalize to 10 digits/)
  end

  it "raises a clear error for non-2xx responses" do
    stub_request(:post, endpoint)
      .to_return(status: 500, body: { error: "provider_down" }.to_json)

    expect do
      described_class.call("5553386115")
    end.to raise_error(Dnc::SuppressionClient::Error, /HTTP 500/)
  end
end
