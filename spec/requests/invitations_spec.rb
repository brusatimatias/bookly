require "rails_helper"

RSpec.describe "Invitations", type: :request do
  let(:business) { create(:business, name: "Barbería Centro") }
  let(:inviter) { create(:user, name: "Lucía") }
  let(:invitation) { create(:invitation, business: business, invited_by: inviter, email: "ana@example.com", role: :professional) }
  let!(:token) { invitation.generate_token_for(:acceptance) }

  let(:new_user_params) { { user: { name: "Ana", password: "secret-password", password_confirmation: "secret-password" } } }

  describe "for an email without an account" do
    it "offers to create the account" do
      get invitation_path(token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Invitación a Barbería Centro", "Lucía te invitó a sumarte como profesional", "Crear cuenta y aceptar")
    end

    it "creates the account, joins the business and signs in" do
      expect { patch invitation_path(token), params: new_user_params }.to change(User, :count).by(1)

      user = User.find_by!(email_address: "ana@example.com")
      expect(user.name).to eq("Ana")
      expect(user.membership_for(business)).to be_professional
      expect(invitation.reload.accepted_at).to be_present
      expect(response).to redirect_to(admin_root_path(business))

      follow_redirect!
      expect(response.body).to include("Ya formás parte de Barbería Centro")
    end

    it "gives the new professional their invited profile" do
      profile = with_business(business) { create(:professional, name: "Ana Torres") }
      invitation.update!(professional: profile)

      patch invitation_path(invitation.generate_token_for(:acceptance)), params: new_user_params

      expect(with_business(business) { profile.reload.user }).to eq(User.find_by!(email_address: "ana@example.com"))
    end

    it "keeps everything unchanged when the account is invalid" do
      params = { user: { name: "", password: "secret-password", password_confirmation: "other-password" } }

      expect { patch invitation_path(token), params: params }.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Nombre no puede estar en blanco")
      expect(invitation.reload.accepted_at).to be_nil
    end

    it "cannot be used twice" do
      patch invitation_path(token), params: new_user_params
      delete session_path

      get invitation_path(token)

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("Invitación no válida")
    end
  end

  describe "for an email with an account" do
    let!(:user) { create(:user, email_address: "ana@example.com") }

    it "asks to sign in and then comes back to the invitation" do
      get invitation_path(token)

      expect(response.body).to include("Iniciá sesión para aceptar")

      sign_in_as(user)
      expect(response).to redirect_to(invitation_url(token))
    end

    it "lets the signed in user accept" do
      sign_in_as(user)

      get invitation_path(token)
      expect(response.body).to include("Aceptar invitación")

      patch invitation_path(token)

      expect(user.membership_for(business)).to be_professional
      expect(response).to redirect_to(admin_root_path(business))
    end

    it "does not accept without signing in" do
      patch invitation_path(token)

      expect(user.membership_for(business)).to be_nil
      expect(response).to redirect_to(invitation_path(token))
    end
  end

  describe "while signed in with another account" do
    before { sign_in_as(create(:user, email_address: "other@example.com")) }

    it "explains who the invitation is for" do
      get invitation_path(token)

      expect(response.body).to include("Esta invitación es para ana@example.com", "other@example.com")
    end

    it "does not accept it" do
      expect { patch invitation_path(token), params: new_user_params }.not_to change(Membership, :count)
    end
  end

  it "is shown in the business language" do
    business.update!(locale: "en")

    get invitation_path(token), headers: { "Accept-Language" => "es" }

    expect(response.body).to include('lang="en"', "Invitation to Barbería Centro")
    expect(response.body).not_to include("Español")
  end

  it "explains when the invitation has expired" do
    travel 8.days do
      get invitation_path(token)
    end

    expect(response).to have_http_status(:gone)
    expect(response.body).to include("Invitación vencida")
  end

  it "rejects an invalid token" do
    get invitation_path("invalid")

    expect(response).to have_http_status(:not_found)
  end

  it "rejects the link of a resent invitation" do
    old_token = token
    travel 1.minute
    invitation.renew!

    get invitation_path(old_token)

    expect(response).to have_http_status(:not_found)
  end

  it "shows the unavailable page when the business is suspended" do
    business.suspend!

    get invitation_path(token)

    expect(response).to have_http_status(:service_unavailable)
  end
end
