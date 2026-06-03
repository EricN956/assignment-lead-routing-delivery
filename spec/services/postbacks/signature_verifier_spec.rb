require "rails_helper"

RSpec.describe Postbacks::SignatureVerifier do
  def signature_for(source_claim_id:, disposition:, secret: "mock-shared-secret")
    Digest::SHA256.hexdigest("#{source_claim_id}:#{disposition}:#{secret}")
  end

  let(:payload) do
    {
      "source_claim_id" => "RAV-SIGNED-1",
      "disposition" => "signed",
      "signature" => signature_for(source_claim_id: "RAV-SIGNED-1", disposition: "signed")
    }
  end

  it "accepts signatures generated with the shared secret" do
    expect(described_class.call(payload)).to be(true)
  end

  it "rejects bad signatures" do
    expect(described_class.call(payload.merge("signature" => "bad"))).to be(false)
  end

  it "rejects missing signatures" do
    expect(described_class.call(payload.except("signature"))).to be(false)
  end

  it "changes expected signature when disposition changes" do
    verifier = described_class.new(payload.merge("disposition" => "rejected"))

    expect(verifier.expected_signature).not_to eq(payload["signature"])
    expect(verifier.valid?).to be(false)
  end
end
