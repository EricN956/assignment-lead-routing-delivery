require "rails_helper"

RSpec.describe AdminUser, type: :model do
  subject(:admin_user) do
    described_class.new(
      email: "admin@example.com",
      password: "password",
      password_confirmation: "password"
    )
  end

  it "is valid with an email and password" do
    expect(admin_user).to be_valid
  end

  it "requires an email" do
    admin_user.email = nil

    expect(admin_user).not_to be_valid
    expect(admin_user.errors[:email]).to be_present
  end
end
