require "rails_helper"

RSpec.describe "Signups", type: :request do
  let(:account) { { name: "Lucía Gómez", email_address: "lucia@example.com", password: "password", password_confirmation: "password" } }
  let(:business_attributes) { { business_name: "Barbería Centro", slug: "", time_zone: "America/Argentina/Buenos_Aires", locale: "es", currency: "ARS" } }

  def sign_up(**attributes)
    post signup_path, params: { business_registration: attributes }
  end

  describe "without an account" do
    it "asks for the account and the business" do
      get new_signup_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Registrá tu negocio", "Tu cuenta", "Tu nombre", "Nombre del negocio", "Dirección web",
                                       "(GMT-03:00) Buenos Aires", "ARS — Peso argentino", ".example.com</span>")
    end

    it "creates the account and the business, signs in and opens the new business's panel" do
      expect { sign_up(**account, **business_attributes) }.to change(User, :count).by(1).and change(Business, :count).by(1)

      business = Business.find_by!(slug: "barberia-centro")
      expect(User.find_by!(email_address: "lucia@example.com").membership_for(business)).to be_owner
      expect(response).to redirect_to(admin_setup_step_path(business, "details"))

      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("¡Listo! Barbería Centro ya está creado.")
    end

    it "greets in the business's language" do
      sign_up(**account, **business_attributes, business_name: "Downtown Studio", locale: "en", time_zone: "America/New_York", currency: "USD")

      follow_redirect!
      expect(response.body).to include("Done! Downtown Studio has been created.")
    end

    it "shows the errors without saving anything" do
      expect { sign_up(**account, **business_attributes, business_name: "", password_confirmation: "other") }.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Nombre del negocio no puede estar en blanco")
    end

    it "offers signing in when the email has an account, and brings them back here" do
      user = create(:user, email_address: "lucia@example.com")

      sign_up(**account, **business_attributes)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Ya hay una cuenta con este email.", new_session_path(email_address: "lucia@example.com"))

      sign_in_as(user)
      expect(response).to redirect_to(new_signup_url)
    end

    it "limits the attempts from one address" do
      10.times { sign_up(**account, **business_attributes, business_name: "") }
      expect(response).to have_http_status(:unprocessable_entity)

      expect { sign_up(**account, **business_attributes) }.not_to change(Business, :count)

      expect(response).to redirect_to(new_signup_path)
      expect(flash[:alert]).to eq("Demasiados intentos. Probá de nuevo más tarde.")
    end
  end

  describe "signed in" do
    let(:user) { create(:user, email_address: "martin@example.com") }

    before { sign_in_as(user) }

    it "asks only for the business" do
      get new_signup_path

      expect(response.body).to include("Vas a administrarlo con tu cuenta martin@example.com.")
      expect(response.body).not_to include("Tu cuenta", "Tu nombre")
    end

    it "adds the business to the user's account" do
      expect { sign_up(**business_attributes) }.not_to change(User, :count)

      business = Business.find_by!(slug: "barberia-centro")
      expect(user.membership_for(business)).to be_owner
      expect(response).to redirect_to(admin_setup_step_path(business, "details"))
    end
  end

  describe "entry points" do
    it "is offered from the landing page and the sign in page" do
      get root_path
      expect(response.body).to include(new_signup_path, "Registrar mi negocio")

      get new_session_path
      expect(response.body).to include(new_signup_path, "Registrá tu negocio")
    end

    it "is offered from the businesses list" do
      user = create(:user)
      create(:membership, business: create(:business), user: user)
      create(:membership, business: create(:business), user: user)
      sign_in_as(user)

      get dashboard_path

      expect(response.body).to include(new_signup_path, "Crear un negocio")
    end
  end
end
