require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let(:user) { create(:user, email_address: "ana@example.com") }

  describe "GET /session/new" do
    it "renders the sign in form" do
      get new_session_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Iniciar sesión")
    end
  end

  describe "POST /session" do
    it "signs in with valid credentials" do
      expect { sign_in_as(user) }.to change(user.sessions, :count).by(1)

      expect(response).to redirect_to(dashboard_url)
      expect(cookies[:session_id]).to be_present
    end

    it "accepts the email address in any case" do
      user
      post session_path, params: { email_address: "ANA@example.com", password: "password" }

      expect(response).to redirect_to(dashboard_url)
    end

    it "rejects a wrong password" do
      expect { sign_in_as(user, password: "wrong-password") }.not_to change(Session, :count)

      expect(response).to redirect_to(new_session_path(email_address: user.email_address))
      expect(flash[:alert]).to eq("El email o la contraseña no son correctos.")
    end
  end

  describe "DELETE /session" do
    it "signs out and ends the session" do
      sign_in_as(user)

      expect { delete session_path }.to change(Session, :count).by(-1)

      expect(response).to redirect_to(new_session_path)
      expect(cookies[:session_id]).to be_blank
    end
  end

  describe "header" do
    it "shows the user and the sign out button when signed in" do
      sign_in_as(user)

      get root_path

      expect(response.body).to include(user.name, "Cerrar sesión")
    end
  end
end
