require "rails_helper"

RSpec.describe "Passwords", type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user, email_address: "ana@example.com") }

  describe "POST /passwords" do
    it "emails reset instructions to a registered address" do
      expect { post passwords_path, params: { email_address: user.email_address } }
        .to have_enqueued_mail(PasswordsMailer, :reset).with(user)

      expect(response).to redirect_to(new_session_path)
    end

    it "responds the same for an unknown address without sending email" do
      expect { post passwords_path, params: { email_address: "nobody@example.com" } }
        .not_to have_enqueued_mail

      expect(response).to redirect_to(new_session_path)
      expect(flash[:notice]).to include("Si el email está registrado")
    end
  end

  describe "GET /passwords/:token/edit" do
    it "renders the form for a valid token" do
      get edit_password_path(user.password_reset_token)

      expect(response).to have_http_status(:ok)
    end

    it "redirects for an invalid token" do
      get edit_password_path("invalid")

      expect(response).to redirect_to(new_password_path)
      expect(flash[:alert]).to include("no es válido")
    end
  end

  describe "PUT /passwords/:token" do
    it "updates the password and ends existing sessions" do
      sign_in_as(user)
      token = user.password_reset_token

      put password_path(token), params: { password: "new-password", password_confirmation: "new-password" }

      expect(response).to redirect_to(new_session_path)
      expect(user.reload.authenticate("new-password")).to be_truthy
      expect(user.sessions).to be_empty
    end

    it "does not accept the token twice" do
      token = user.password_reset_token
      put password_path(token), params: { password: "new-password", password_confirmation: "new-password" }

      get edit_password_path(token)

      expect(response).to redirect_to(new_password_path)
    end

    it "rejects a confirmation that does not match" do
      token = user.password_reset_token

      put password_path(token), params: { password: "new-password", password_confirmation: "other-password" }

      expect(response).to redirect_to(edit_password_path(token))
      expect(user.reload.authenticate("password")).to be_truthy
    end
  end
end
