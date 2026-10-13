require "rails_helper"

RSpec.describe Membership, type: :model do
  let(:business) { create(:business) }

  it "is valid with the factory defaults" do
    expect(build(:membership)).to be_valid
  end

  describe "role" do
    it "rejects unknown roles" do
      membership = build(:membership, role: "guest")

      expect(membership).not_to be_valid
      expect(membership.errors).to be_of_kind(:role, :inclusion)
    end

    it "is checked in the database" do
      membership = create(:membership)

      expect { membership.update_column(:role, "guest") }.to raise_error(ActiveRecord::StatementInvalid, /memberships_role_valid/)
    end
  end

  describe "one role per person and business" do
    it "rejects a second membership for the same user" do
      user = create(:user)
      create(:membership, business: business, user: user, role: :admin)
      duplicate = build(:membership, business: business, user: user, role: :professional)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors).to be_of_kind(:user_id, :taken)
    end

    it "is enforced in the database" do
      user = create(:user)
      create(:membership, business: business, user: user)
      duplicate = build(:membership, business: business, user: user)

      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows the same user in another business" do
      user = create(:user)
      create(:membership, business: business, user: user, role: :owner)

      expect(build(:membership, user: user, role: :professional)).to be_valid
    end
  end

  describe "a single owner per business" do
    before { create(:membership, :owner, business: business) }

    it "rejects a second owner" do
      second = build(:membership, :owner, business: business)

      expect(second).not_to be_valid
      expect(second.errors).to be_of_kind(:role, :taken)
    end

    it "translates the error" do
      second = build(:membership, :owner, business: business)
      second.validate

      expect(second.errors.full_messages).to include("Rol de dueño ya está asignado en este negocio")
    end

    it "is enforced in the database" do
      second = build(:membership, :owner, business: business)

      expect { second.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows several admins and professionals" do
      create(:membership, :admin, business: business)
      create(:membership, :admin, business: business)
      create(:membership, business: business)

      expect(business.memberships.count).to eq(4)
    end
  end

  describe "#manager?" do
    it "is true for owners and admins only" do
      expect(build(:membership, :owner)).to be_manager
      expect(build(:membership, :admin)).to be_manager
      expect(build(:membership)).not_to be_manager
    end
  end

  describe "associations" do
    it "exposes the owner and members of a business" do
      owner = create(:membership, :owner, business: business).user
      professional = create(:membership, business: business).user

      expect(business.owner).to eq(owner)
      expect(business.members).to contain_exactly(owner, professional)
    end

    it "finds the membership of a user in a business" do
      membership = create(:membership, business: business)

      expect(membership.user.membership_for(business)).to eq(membership)
      expect(membership.user.membership_for(create(:business))).to be_nil
    end

    it "removes the memberships of a deleted user" do
      membership = create(:membership, business: business)

      expect { membership.user.destroy }.to change(described_class, :count).by(-1)
    end
  end

  describe "#remove!" do
    let(:membership) { create(:membership, business: business) }

    it "removes the member from the business, keeping the user" do
      membership.remove!

      expect(described_class.exists?(membership.id)).to be(false)
      expect(User.exists?(membership.user_id)).to be(true)
    end

    it "keeps their professional profile, inactive and unlinked" do
      profile = with_business(business) { create(:professional, user: membership.user) }

      membership.remove!

      with_business(business) do
        expect(profile.reload).to have_attributes(user: nil, active: false)
      end
    end

    it "leaves their profiles in other businesses alone" do
      other = create(:membership, user: membership.user)
      profile = with_business(other.business) { create(:professional, user: other.user) }

      membership.remove!

      with_business(other.business) do
        expect(profile.reload).to have_attributes(user: other.user, active: true)
      end
    end

    it "does not remove the owner" do
      owner = create(:membership, :owner, business: business)

      expect { owner.remove! }.to raise_error(Membership::NotRemovable)
      expect(described_class.exists?(owner.id)).to be(true)
    end
  end

  describe "#change_role" do
    let(:membership) { create(:membership, :admin, business: business) }

    it "switches an admin to professional, creating their profile" do
      membership.user.update!(name: "Ana Pérez")

      expect(membership.change_role("professional")).to be(true)

      expect(membership.reload).to be_professional
      expect(membership.professional_profile).to have_attributes(name: "Ana Pérez", active: true)
    end

    it "keeps the existing profile when switching to professional" do
      profile = with_business(business) { create(:professional, user: membership.user) }

      membership.change_role("professional")

      expect(membership.professional_profile).to eq(profile)
      expect(with_business(business) { Professional.count }).to eq(1)
    end

    it "lets a professional become an admin, keeping their profile" do
      membership = create(:membership, business: business)
      profile = with_business(business) { create(:professional, user: membership.user) }

      expect(membership.change_role("admin")).to be(true)

      expect(membership.reload).to be_admin
      expect(membership.professional_profile).to eq(profile)
    end

    it "does not make anyone the owner" do
      expect(membership.change_role("owner")).to be(false)

      expect(membership.errors).to be_of_kind(:role, :owner_unchangeable)
      expect(membership.reload).to be_admin
    end

    it "does not change the owner's role" do
      owner = create(:membership, :owner, business: business)

      expect(owner.change_role("admin")).to be(false)

      expect(owner.reload).to be_owner
      expect(with_business(business) { Professional.count }).to eq(0)
    end

    it "rejects unknown roles" do
      expect(membership.change_role("guest")).to be(false)

      expect(membership.errors).to be_of_kind(:role, :inclusion)
    end
  end
end
