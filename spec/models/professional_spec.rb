require "rails_helper"

RSpec.describe Professional, type: :model do
  let(:business) { create(:business) }

  around { |example| with_business(business) { example.run } }

  def member(role: :professional)
    create(:membership, business: business, role: role).user
  end

  it "is valid with the factory defaults" do
    expect(build(:professional)).to be_valid
  end

  it "requires a name" do
    professional = build(:professional, name: " ")

    expect(professional).not_to be_valid
    expect(professional.errors).to be_of_kind(:name, :blank)
  end

  describe "linked member" do
    it "lends its name to a profile without one" do
      user = member
      user.update!(name: "Martín Gómez")

      expect(create(:professional, name: "", user: user).name).to eq("Martín Gómez")
    end

    it "is optional" do
      expect(build(:professional, user: nil)).to be_valid
    end

    it "can be any member of the business, including managers" do
      expect(build(:professional, user: member(role: :owner))).to be_valid
    end

    it "must be a member of the business" do
      professional = build(:professional, user: create(:user))

      expect(professional).not_to be_valid
      expect(professional.errors).to be_of_kind(:user, :not_a_member)
    end

    it "must be a member of the business in the database" do
      professional = build(:professional, user: create(:user))

      expect { professional.save(validate: false) }.to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it "rejects a member of another business" do
      outsider = create(:membership).user
      professional = build(:professional, user: outsider)

      expect(professional).not_to be_valid
      expect(professional.errors).to be_of_kind(:user, :not_a_member)
    end

    it "has a single profile per business" do
      user = member
      create(:professional, user: user)
      duplicate = build(:professional, user: user)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors).to be_of_kind(:user_id, :taken)
      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "keeps the membership from being removed while linked" do
      user = member
      create(:professional, user: user)

      expect { Membership.find_by!(business: business, user: user).delete }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end

  describe "services" do
    it "offers services of its business" do
      services = create_list(:service, 2)
      professional = create(:professional, services: services)

      expect(professional.reload.services).to match_array(services)
    end

    it "can't offer the same service twice" do
      service = create(:service)
      professional = create(:professional, services: [ service ])

      expect { ProfessionalService.new(professional: professional, service: service).save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "can't offer a service of another business" do
      other_service = with_business(create(:business)) { create(:service) }
      professional = create(:professional)

      expect { professional.service_ids = [ other_service.id ] }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "can't offer a service of another business in the database" do
      other_service = with_business(create(:business)) { create(:service) }
      professional = create(:professional)
      link = ProfessionalService.new(professional: professional, service_id: other_service.id)

      expect { link.save(validate: false) }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end

  describe "photo" do
    def attach(professional, file, content_type)
      professional.photo.attach(io: file_fixture(file).open, filename: file, content_type: content_type)
    end

    it "accepts an image" do
      professional = build(:professional)
      attach(professional, "photo.png", "image/png")

      expect(professional).to be_valid
    end

    it "rejects other files" do
      professional = build(:professional)
      attach(professional, "notes.txt", "text/plain")

      expect(professional).not_to be_valid
      expect(professional.errors).to be_of_kind(:photo, :invalid_content_type)
    end

    it "rejects large images" do
      stub_const("Professional::PHOTO_MAX_SIZE", 10)
      professional = build(:professional)
      attach(professional, "photo.png", "image/png")

      expect(professional).not_to be_valid
      expect(professional.errors).to be_of_kind(:photo, :too_large)
    end
  end

  describe ".bookable" do
    it "includes active professionals offering an active service, with weekly hours" do
      bookable = create(:professional, :with_hours, services: [ create(:service) ])
      create(:professional, :inactive, :with_hours, services: [ create(:service) ])
      create(:professional, :with_hours, services: [ create(:service, :inactive) ])
      create(:professional, :with_hours)
      create(:professional, services: [ create(:service) ])

      expect(described_class.bookable).to contain_exactly(bookable)
    end
  end

  describe "#bookable?" do
    it "is true for an active professional offering an active service, with weekly hours" do
      expect(create(:professional, :with_hours, services: [ create(:service) ])).to be_bookable
    end

    it "is false without services" do
      expect(create(:professional, :with_hours)).not_to be_bookable
    end

    it "is false when all their services are inactive" do
      expect(create(:professional, :with_hours, services: [ create(:service, :inactive) ])).not_to be_bookable
    end

    it "is false without weekly hours" do
      expect(create(:professional, services: [ create(:service) ])).not_to be_bookable
    end

    it "is false when inactive" do
      expect(create(:professional, :inactive, :with_hours, services: [ create(:service) ])).not_to be_bookable
    end
  end

  it "deactivates without losing its services" do
    service = create(:service)
    professional = create(:professional, services: [ service ])

    professional.deactivate!

    expect(professional.reload).not_to be_active
    expect(professional.services).to contain_exactly(service)
  end
end
