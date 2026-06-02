require "rails_helper"

RSpec.describe Leads::PhoneNormalizer do
  it "keeps valid 10 digit phone numbers" do
    expect(described_class.call("5553386115")).to eq("5553386115")
  end

  it "strips formatting and US country code" do
    expect(described_class.call("+1 (555) 314-2271")).to eq("5553142271")
  end

  it "returns nil for malformed phone numbers" do
    expect(described_class.call("(555) 123-99")).to be_nil
  end

  it "returns nil for blank phone numbers" do
    expect(described_class.call("")).to be_nil
  end
end
