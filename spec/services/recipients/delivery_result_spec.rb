require "rails_helper"

RSpec.describe Recipients::DeliveryResult do
  let(:request) do
    {
      "method" => "POST",
      "url" => "http://localhost:3100/apex/v2/leads",
      "headers" => {},
      "body" => {}
    }
  end

  let(:response) do
    {
      "status" => 202,
      "headers" => {},
      "body" => { "claim_id" => "APX-123" }
    }
  end

  it "represents accepted deliveries" do
    result = described_class.accepted(
      external_id: "APX-123",
      request: request,
      response: response
    )

    expect(result).to be_successful
    expect(result).to be_accepted
    expect(result.delivery_status).to eq("delivered")
    expect(result.to_h).to include(
      "status" => "accepted",
      "delivery_status" => "delivered",
      "external_id" => "APX-123"
    )
  end

  it "represents duplicate accepted deliveries" do
    result = described_class.duplicate_accepted(
      external_id: "BCN-123",
      request: request,
      response: response
    )

    expect(result).to be_successful
    expect(result).to be_duplicate_accepted
    expect(result.delivery_status).to eq("duplicate_accepted")
  end

  it "represents retryable failures" do
    result = described_class.retryable_failure(
      error_code: "rate_limited",
      error_message: "Retry later",
      retry_after_seconds: 30,
      request: request,
      response: response
    )

    expect(result).to be_failed
    expect(result).to be_retryable
    expect(result.delivery_status).to eq("retrying")
    expect(result.retry_after_seconds).to eq(30)
  end

  it "represents permanent failures" do
    result = described_class.rejected_failure(
      error_code: "validation_failed",
      error_message: "Missing field",
      request: request,
      response: response
    )

    expect(result).to be_failed
    expect(result).to be_permanent_failure
    expect(result.delivery_status).to eq("failed")
  end

  it "rejects unsupported statuses" do
    expect do
      described_class.new(
        status: "weird",
        request: request,
        response: response
      )
    end.to raise_error(Recipients::InvalidDeliveryResult, /Unsupported status/)
  end
end
