require "rails_helper"

RSpec.describe User, type: :model do
  it "is valid with the factory defaults" do
    expect(build(:user)).to be_valid
  end

  it "is not a platform admin by default" do
    expect(create(:user)).not_to be_platform_admin
  end

  it "requires a name" do
    user = build(:user, name: "")

    expect(user).not_to be_valid
    expect(user.errors).to be_of_kind(:name, :blank)
  end

  it "normalizes the email address" do
    expect(build(:user, email_address: "  Ana@Example.COM ").email_address).to eq("ana@example.com")
  end

  it "rejects malformed email addresses" do
    user = build(:user, email_address: "not-an-email")

    expect(user).not_to be_valid
    expect(user.errors).to be_of_kind(:email_address, :invalid)
  end

  it "requires a unique email address regardless of case" do
    create(:user, email_address: "ana@example.com")
    user = build(:user, email_address: "ANA@example.com")

    expect(user).not_to be_valid
    expect(user.errors).to be_of_kind(:email_address, :taken)
  end

  it "enforces unique email addresses in the database" do
    create(:user, email_address: "ana@example.com")
    duplicate = build(:user, email_address: "ana@example.com")

    expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "requires passwords of at least 8 characters" do
    user = build(:user, password: "short")

    expect(user).not_to be_valid
    expect(user.errors).to be_of_kind(:password, :too_short)
  end

  it "does not require the password when updating other attributes" do
    user = User.find(create(:user).id)

    expect(user.update(name: "New name")).to be(true)
  end
end
