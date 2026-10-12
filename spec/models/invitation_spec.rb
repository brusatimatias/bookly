require "rails_helper"

RSpec.describe Invitation, type: :model do
  let(:business) { create(:business) }

  def acceptance_token(invitation)
    invitation.generate_token_for(:acceptance)
  end

  def find_by_token(token)
    described_class.find_by_token_for(:acceptance, token)
  end

  it "is valid with the factory defaults" do
    expect(build(:invitation)).to be_valid
  end

  it "expires in 7 days" do
    freeze_time do
      expect(create(:invitation).expires_at).to eq(7.days.from_now)
    end
  end

  it "normalizes the email" do
    expect(build(:invitation, email: "  Ana@Example.COM ").email).to eq("ana@example.com")
  end

  describe "role" do
    it "only allows admins and professionals" do
      invitation = build(:invitation, role: "owner")

      expect(invitation).not_to be_valid
      expect(invitation.errors).to be_of_kind(:role, :inclusion)
    end

    it "is checked in the database" do
      invitation = create(:invitation)

      expect { invitation.update_column(:role, "owner") }.to raise_error(ActiveRecord::StatementInvalid, /invitations_role_valid/)
    end
  end

  describe "email" do
    it "cannot have two pending invitations in the same business" do
      create(:invitation, business: business, email: "ana@example.com")
      duplicate = build(:invitation, business: business, email: "ANA@example.com")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors).to be_of_kind(:email, :taken)
      expect(duplicate.errors.full_messages.first).to include("ya tiene una invitación pendiente")
    end

    it "is unique among pending invitations in the database" do
      create(:invitation, business: business, email: "ana@example.com")
      duplicate = build(:invitation, business: business, email: "ana@example.com")

      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "can be invited again once the previous invitation was accepted" do
      create(:invitation, business: business, email: "ana@example.com", accepted_at: Time.current)

      expect(build(:invitation, business: business, email: "ana@example.com")).to be_valid
    end

    it "can be invited to another business" do
      create(:invitation, business: business, email: "ana@example.com")

      expect(build(:invitation, email: "ana@example.com")).to be_valid
    end

    it "cannot belong to a member of the business" do
      create(:membership, business: business, user: create(:user, email_address: "ana@example.com"))
      invitation = build(:invitation, business: business, email: "ana@example.com")

      expect(invitation).not_to be_valid
      expect(invitation.errors).to be_of_kind(:email, :already_member)
    end
  end

  describe "acceptance token" do
    it "finds the invitation" do
      invitation = create(:invitation)

      expect(find_by_token(acceptance_token(invitation))).to eq(invitation)
    end

    it "finds the invitation from a token generated in another time zone" do
      invitation = create(:invitation)
      token = Time.use_zone("America/Argentina/Buenos_Aires") { acceptance_token(invitation) }

      expect(Time.use_zone("UTC") { find_by_token(token) }).to eq(invitation)
    end

    it "stops working once the invitation is accepted" do
      invitation = create(:invitation)
      token = acceptance_token(invitation)

      invitation.update!(accepted_at: Time.current)

      expect(find_by_token(token)).to be_nil
    end

    it "stops working when the invitation is renewed" do
      invitation = create(:invitation)
      token = acceptance_token(invitation)

      travel 1.minute
      invitation.renew!

      expect(find_by_token(token)).to be_nil
      expect(find_by_token(acceptance_token(invitation))).to eq(invitation)
    end

    it "stops working when the invitation is revoked" do
      invitation = create(:invitation)
      token = acceptance_token(invitation)

      invitation.destroy!

      expect(find_by_token(token)).to be_nil
    end
  end

  describe "#accept!" do
    let!(:invitation) { create(:invitation, business: business, email: "ana@example.com", role: :admin) }
    let!(:user) { create(:user, email_address: "ana@example.com") }

    it "adds the user to the business with the invited role" do
      freeze_time do
        invitation.accept!(user)

        expect(user.membership_for(business)).to be_admin
        expect(invitation.reload.accepted_at).to eq(Time.current)
      end
    end

    it "cannot be accepted twice" do
      invitation.accept!(user)

      expect { invitation.accept!(user) }.to raise_error(Invitation::NotAcceptable)
    end

    it "cannot be accepted once expired" do
      travel 8.days do
        expect { invitation.accept!(user) }.to raise_error(Invitation::NotAcceptable)
      end
      expect(business.memberships).to be_empty
    end

    it "cannot be accepted by someone with another email" do
      expect { invitation.accept!(create(:user)) }.to raise_error(Invitation::NotAcceptable)
    end

    it "gives admins no professional profile" do
      invitation.accept!(user)

      expect(with_business(business) { Professional.count }).to eq(0)
    end

    describe "as a professional" do
      let!(:invitation) { create(:invitation, business: business, email: "ana@example.com", role: :professional) }

      before { user.update!(name: "Ana Pérez") }

      it "creates a profile with the user's name" do
        invitation.accept!(user)

        profile = with_business(business) { Professional.find_by!(user: user) }
        expect(profile.name).to eq("Ana Pérez")
      end

      it "takes over the invited profile, keeping its name and services" do
        profile, service = with_business(business) do
          service = create(:service)
          [ create(:professional, name: "Ana", services: [ service ]), service ]
        end
        invitation.update!(professional: profile)

        invitation.accept!(user)

        with_business(business) do
          expect(profile.reload).to have_attributes(user: user, name: "Ana")
          expect(profile.services).to contain_exactly(service)
          expect(Professional.count).to eq(1)
        end
      end

      it "gets a profile of their own if the invited one was linked in the meantime" do
        profile = with_business(business) { create(:professional) }
        invitation.update!(professional: profile)
        other = create(:membership, business: business).user
        with_business(business) { profile.update!(user: other) }

        invitation.accept!(user)

        with_business(business) do
          expect(profile.reload.user).to eq(other)
          expect(Professional.find_by(user: user)).to be_present
        end
      end
    end
  end

  describe "professional profile" do
    let(:profile) { with_business(business) { create(:professional) } }

    it "is optional" do
      expect(build(:invitation, business: business, professional: nil)).to be_valid
    end

    it "cannot already have an account" do
      user = create(:membership, business: business).user
      with_business(business) { profile.update!(user: user) }

      invitation = build(:invitation, business: business, professional: profile)

      with_business(business) do
        expect(invitation).not_to be_valid
        expect(invitation.errors).to be_of_kind(:professional, :already_linked)
      end
    end

    it "has a single pending invitation" do
      create(:invitation, business: business, professional: profile)
      duplicate = build(:invitation, business: business, professional: profile)

      with_business(business) do
        expect(duplicate).not_to be_valid
        expect(duplicate.errors).to be_of_kind(:professional_id, :taken)
      end
      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "must belong to the same business in the database" do
      invitation = build(:invitation, professional_id: profile.id)

      expect { invitation.save(validate: false) }.to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it "can be renewed without a current business" do
      invitation = create(:invitation, business: business, professional: profile)

      expect { invitation.renew! }.not_to raise_error
    end
  end

  describe "#renew!" do
    it "extends the expiration by 7 days from now" do
      invitation = create(:invitation)

      travel 10.days do
        invitation.renew!

        expect(invitation.expires_at).to be_within(1.second).of(7.days.from_now)
        expect(invitation).not_to be_expired
      end
    end
  end

  describe "#expired?" do
    it "is true after the expiration date" do
      invitation = create(:invitation)

      expect(invitation).not_to be_expired
      travel 8.days do
        expect(invitation).to be_expired
      end
    end
  end
end
