require "rails_helper"

RSpec.describe Recipients::ClientRegistry do
  before do
    stub_const(
      "Recipients::RegistrySpecClient",
      Class.new(Recipients::BaseClient) do
        def deliver(_lead)
          Recipients::DeliveryResult.accepted(
            external_id: "SPEC-1",
            request: {},
            response: {}
          )
        end
      end
    )
  end

  def build_recipient(client_class:)
    Recipient.create!(
      code: "registry_spec_#{SecureRandom.hex(4)}",
      name: "Registry Spec",
      accepted_states: %w[TX],
      base_url: "http://localhost:3100",
      endpoint_path: "/spec",
      auth_type: "none",
      client_class: client_class
    )
  end

  it "builds a configured recipient client" do
    recipient = build_recipient(client_class: "Recipients::RegistrySpecClient")

    client = described_class.build(recipient)

    expect(client).to be_a(Recipients::RegistrySpecClient)
    expect(client.recipient).to eq(recipient)
  end

  it "raises a clear error when the class is missing" do
    recipient = build_recipient(client_class: "Recipients::MissingClient")

    expect do
      described_class.build(recipient)
    end.to raise_error(Recipients::ClientClassNotFound, /not found/)
  end

  it "raises a clear error when the class does not inherit from BaseClient" do
    stub_const("Recipients::BadClient", Class.new)
    recipient = build_recipient(client_class: "Recipients::BadClient")

    expect do
      described_class.build(recipient)
    end.to raise_error(Recipients::ClientClassNotFound, /must inherit/)
  end
end
