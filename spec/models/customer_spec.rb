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

  describe "#busy_during?" do
    let(:customer) { create(:customer) }
    let(:starts_at) { 1.day.from_now.change(hour: 10) }
    let!(:appointment) { create(:appointment, customer: customer, starts_at: starts_at) }

    it "is true when an active appointment's service overlaps the range" do
      expect(customer.busy_during?((starts_at + 10.minutes)...(starts_at + 1.hour))).to be(true)
      expect(customer.busy_during?(appointment.ends_at...(appointment.ends_at + 1.hour))).to be(false)
    end

    it "ignores appointments that no longer hold their time, and the one left out" do
      range = starts_at...(starts_at + 1.hour)

      expect(customer.busy_during?(range, except: appointment)).to be(false)
      appointment.update_column(:status, "cancelled")
      expect(customer.busy_during?(range)).to be(false)
    end
  end
end
