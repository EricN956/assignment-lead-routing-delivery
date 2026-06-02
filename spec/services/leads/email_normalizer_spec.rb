require "rails_helper"

RSpec.describe Leads::EmailNormalizer do
  it "trims and lowercases email addresses" do
    expect(described_class.call(" User1001@Example.COM ")).to eq("user1001@example.com")
  end

  it "returns nil for blank email addresses" do
    expect(described_class.call(" ")).to be_nil
  end
end
