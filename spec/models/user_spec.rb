require "rails_helper"

RSpec.describe User, type: :model do
  it "has a valid factory" do
    expect(build(:user)).to be_valid
  end

  it { is_expected.to have_many(:sessions).dependent(:destroy) }
  it { is_expected.to have_secure_password }

  it "normalizes the email address by stripping and downcasing" do
    user = create(:user, email_address: "  Fabian@Example.COM  ")
    expect(user.email_address).to eq("fabian@example.com")
  end

  it "requires a unique email address" do
    create(:user, email_address: "dup@example.com")
    duplicate = build(:user, email_address: "dup@example.com")
    expect(duplicate).not_to be_valid
  end
end
