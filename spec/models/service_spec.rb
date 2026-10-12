require "rails_helper"

RSpec.describe Service, type: :model do
  let(:business) { create(:business) }

  around { |example| with_business(business) { example.run } }

  it "is valid with the factory defaults" do
    expect(build(:service)).to be_valid
  end

  it "belongs to the current business" do
    expect(create(:service).business).to eq(business)
  end

  it "squishes the name" do
    expect(build(:service, name: "  Corte   de pelo ").name).to eq("Corte de pelo")
  end

  describe "name" do
    it "is required" do
      service = build(:service, name: "")

      expect(service).not_to be_valid
      expect(service.errors).to be_of_kind(:name, :blank)
    end

    it "is unique per business, ignoring case" do
      create(:service, name: "Corte")
      duplicate = build(:service, name: "CORTE")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors).to be_of_kind(:name, :taken)
    end

    it "is unique per business in the database" do
      create(:service, name: "Corte")

      expect { build(:service, name: "corte").save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "can repeat in another business" do
      create(:service, name: "Corte")

      with_business(create(:business)) do
        expect(build(:service, name: "Corte")).to be_valid
      end
    end
  end

  describe "duration" do
    it "must be positive" do
      service = build(:service, duration_minutes: 0)

      expect(service).not_to be_valid
      expect(service.errors).to be_of_kind(:duration_minutes, :greater_than)
    end

    it "can't exceed a day" do
      service = build(:service, duration_minutes: Service::MAX_DURATION_MINUTES + 1)

      expect(service).not_to be_valid
      expect(service.errors).to be_of_kind(:duration_minutes, :less_than_or_equal_to)
    end

    it "is checked in the database" do
      service = create(:service)

      expect { service.update_column(:duration_minutes, 0) }.to raise_error(ActiveRecord::StatementInvalid, /services_duration_positive/)
    end
  end

  describe "price" do
    it "can be zero" do
      expect(build(:service, price_cents: 0)).to be_valid
    end

    it "can't be negative" do
      service = build(:service, price_cents: -1)

      expect(service).not_to be_valid
      expect(service.errors).to be_of_kind(:price_cents, :greater_than_or_equal_to)
    end

    it "is checked in the database" do
      service = create(:service)

      expect { service.update_column(:price_cents, -1) }.to raise_error(ActiveRecord::StatementInvalid, /services_price_non_negative/)
    end
  end

  describe "buffer" do
    it "is optional, falling back to the business's" do
      expect(build(:service, buffer_minutes: nil)).to be_valid
    end

    it "can't be negative" do
      service = build(:service, buffer_minutes: -5)

      expect(service).not_to be_valid
      expect(service.errors).to be_of_kind(:buffer_minutes, :greater_than_or_equal_to)
    end
  end

  it "stores a rich text description" do
    service = create(:service, description: "<strong>Includes</strong> a wash")

    expect(service.reload.description.to_plain_text).to eq("Includes a wash")
  end

  describe "deactivation" do
    it "is active by default" do
      expect(create(:service)).to be_active
    end

    it "deactivates and reactivates" do
      service = create(:service)

      service.deactivate!
      expect(service.reload).not_to be_active

      service.reactivate!
      expect(service.reload).to be_active
    end

    it "filters active and inactive services" do
      active = create(:service)
      inactive = create(:service, :inactive)

      expect(described_class.active).to contain_exactly(active)
      expect(described_class.inactive).to contain_exactly(inactive)
    end

    it "can't be destroyed while professionals offer it" do
      service = create(:service)
      create(:professional, services: [ service ])

      expect { service.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
    end
  end
end
