require "rails_helper"

RSpec.describe Customer, type: :model do
  let(:business) { create(:business) }

  around { |example| with_business(business) { example.run } }

  it "is valid with the factory defaults" do
    expect(build(:customer)).to be_valid
  end

  it "normalizes its email, name and phone" do
    customer = build(:customer, email: "  Ana@Example.COM ", name: " Ana   Pérez ", phone: "  ")

    expect(customer).to have_attributes(email: "ana@example.com", name: "Ana Pérez", phone: nil)
  end

  it "requires a valid email and a name" do
    customer = build(:customer, email: "ana", name: "")

    expect(customer).not_to be_valid
    expect(customer.errors).to be_of_kind(:email, :invalid)
    expect(customer.errors).to be_of_kind(:name, :blank)
  end

  describe "email" do
    before { create(:customer, email: "ana@example.com") }

    it "is unique within the business" do
      duplicate = build(:customer, email: "ANA@example.com")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors).to be_of_kind(:email, :taken)
      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "can repeat in another business" do
      expect(with_business(create(:business)) { build(:customer, email: "ana@example.com").valid? }).to be(true)
    end
  end
end
