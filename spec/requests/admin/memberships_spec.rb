require "rails_helper"

RSpec.describe "Admin memberships", type: :request do
  let(:business) { create(:business) }
  let!(:owner) { create(:membership, :owner, business: business).user }
  let!(:member) { create(:membership, business: business, user: create(:user, name: "Ana")) }

  describe "removing a member" do
    it "lets the owner remove a member" do
      sign_in_as(owner)

      delete admin_membership_path(business, member)

      expect(response).to redirect_to(admin_team_path(business))
      expect(flash[:notice]).to eq("Quitamos a Ana del equipo.")
      expect(Membership.exists?(member.id)).to be(false)
    end

    it "deactivates the member's professional profile" do
      profile = with_business(business) { create(:professional, user: member.user) }
      sign_in_as(owner)

      delete admin_membership_path(business, member)

      with_business(business) do
        expect(profile.reload).to have_attributes(user: nil, active: false)
      end
    end

    it "takes away the removed member's access to the panel" do
      sign_in_as(owner)
      delete admin_membership_path(business, member)

      sign_in_as(member.user)
      get admin_root_path(business)

      expect(response).to have_http_status(:not_found)
    end

    it "does not remove the owner" do
      sign_in_as(owner)

      delete admin_membership_path(business, owner.membership_for(business))

      expect(response).to redirect_to(admin_team_path(business))
      expect(flash[:alert]).to eq("El dueño no puede quitarse del equipo.")
      expect(owner.membership_for(business)).to be_present
    end

    it "is only available to the owner" do
      admin = create(:membership, :admin, business: business).user
      sign_in_as(admin)

      delete admin_membership_path(business, member)

      expect(response).to redirect_to(admin_root_path(business))
      expect(Membership.exists?(member.id)).to be(true)
    end

    it "responds not found for members of other businesses" do
      other = create(:membership)
      sign_in_as(owner)

      delete admin_membership_path(business, other)

      expect(response).to have_http_status(:not_found)
      expect(Membership.exists?(other.id)).to be(true)
    end
  end
end
