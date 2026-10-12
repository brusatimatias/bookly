require "rails_helper"

RSpec.describe "Admin invitations", type: :request do
  let(:business) { create(:business) }
  let(:owner) { create(:membership, :owner, business: business).user }

  describe "as the owner" do
    before { sign_in_as(owner) }

    it "renders the form" do
      get new_admin_invitation_path(business)

      expect(response).to have_http_status(:ok)
    end

    it "invites by email" do
      expect {
        post admin_invitations_path(business), params: { invitation: { email: "ana@example.com", role: "admin" } }
      }.to change(business.invitations, :count).by(1)
        .and have_enqueued_mail(InvitationsMailer, :invite)

      invitation = business.invitations.last
      expect(invitation).to have_attributes(email: "ana@example.com", role: "admin", invited_by: owner)
      expect(response).to redirect_to(admin_team_path(business))
    end

    it "shows errors for an invalid invitation" do
      post admin_invitations_path(business), params: { invitation: { email: "not-an-email", role: "professional" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Email no es válido")
    end

    it "resends an invitation with a new term, voiding the previous link" do
      invitation = create(:invitation, business: business, invited_by: owner)
      old_token = invitation.generate_token_for(:acceptance)

      travel 1.day do
        expect { post resend_admin_invitation_path(business, invitation) }
          .to have_enqueued_mail(InvitationsMailer, :invite)
      end

      expect(response).to redirect_to(admin_team_path(business))
      expect(Invitation.find_by_token_for(:acceptance, old_token)).to be_nil
    end

    it "revokes an invitation" do
      invitation = create(:invitation, business: business, invited_by: owner)

      expect { delete admin_invitation_path(business, invitation) }.to change(Invitation, :count).by(-1)

      expect(response).to redirect_to(admin_team_path(business))
    end

    it "cannot touch invitations of another business" do
      invitation = create(:invitation)

      delete admin_invitation_path(business, invitation)

      expect(response).to have_http_status(:not_found)
      expect(Invitation.exists?(invitation.id)).to be(true)
    end
  end

  describe "as an admin" do
    before do
      admin = create(:user)
      create(:membership, :admin, business: business, user: admin)
      sign_in_as(admin)
    end

    it "cannot invite" do
      expect {
        post admin_invitations_path(business), params: { invitation: { email: "ana@example.com", role: "professional" } }
      }.not_to change(Invitation, :count)

      expect(response).to redirect_to(admin_root_path(business))
    end

    it "cannot revoke invitations" do
      invitation = create(:invitation, business: business)

      expect { delete admin_invitation_path(business, invitation) }.not_to change(Invitation, :count)
    end
  end
end
