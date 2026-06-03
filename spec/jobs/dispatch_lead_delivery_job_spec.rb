require "rails_helper"

RSpec.describe DispatchLeadDeliveryJob, type: :job do
  it "delegates execution to the delivery executor" do
    lead = Lead.create!(
      source_claim_id: "RAV-JOB-#{SecureRandom.hex(4)}",
      publisher: "publisher_alpha",
      stage: "routed"
    )

    recipient = Recipient.create!(
      code: "job_recipient_#{SecureRandom.hex(4)}",
      name: "Job Recipient",
      accepted_states: %w[TX],
      base_url: "http://localhost:3100",
      endpoint_path: "/job",
      auth_type: "none",
      client_class: "Recipients::JobClient"
    )

    delivery = LeadDelivery.create!(lead: lead, recipient: recipient)

    allow(Leads::Dispatch::DeliveryExecutor).to receive(:call)

    described_class.perform_now(delivery.id)

    expect(Leads::Dispatch::DeliveryExecutor).to have_received(:call).with(delivery)
  end

  it "discards missing delivery records" do
    expect do
      described_class.perform_now(-1)
    end.not_to raise_error
  end
end
