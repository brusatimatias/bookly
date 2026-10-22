require "rails_helper"

RSpec.describe "Admin business details", type: :request do
  let(:business) { create(:business, name: "Barbería Centro", contact_email: "hola@centro.example", address: "Av. Corrientes 1234") }

  def sign_in_with_role(role)
    user = create(:user)
    create(:membership, business: business, user: user, role: role)
    sign_in_as(user)
  end

  let(:details) do
    { name: "Barbería Centro Palermo", contact_email: "palermo@centro.example", contact_phone: "+54 11 5555-0000",
      address: "Honduras 4800", time_zone: "America/Montevideo", locale: "es", currency: "UYU" }
  end

  describe "as the owner" do
    before { sign_in_with_role(:owner) }

    it "shows the details, the fixed web address and the settings tabs" do
      get edit_admin_business_path(business)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Datos del negocio", 'value="Barbería Centro"', 'value="hola@centro.example"',
                                       "http://#{business_host(business)}/", "La dirección web no se puede cambiar",
                                       "Los precios no se convierten", edit_admin_settings_path(business))
    end

    it "updates them" do
      patch admin_business_path(business), params: { business: details }

      expect(response).to redirect_to(edit_admin_business_path(business))
      expect(flash[:notice]).to eq("Guardamos los datos del negocio.")
      expect(business.reload).to have_attributes(details)
    end

    it "shows the confirmation and the panel in the new language" do
      patch admin_business_path(business), params: { business: details.merge(locale: "en") }

      follow_redirect!
      expect(response.body).to include("Business details saved.", "Business details")
    end

    it "shows the errors, keeping the saved name around the form" do
      patch admin_business_path(business), params: { business: details.merge(name: "", contact_email: "nope", currency: "XYZ") }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Nombre no puede estar en blanco", "Email de contacto no es válido", "Moneda no está incluido en la lista")
      expect(response.body).to include("Barbería Centro")
      expect(business.reload.name).to eq("Barbería Centro")
    end

    it "never changes the web address or the booking settings" do
      patch admin_business_path(business), params: { business: details.merge(slug: "otro", slot_interval_minutes: 5) }

      expect(business.reload).to have_attributes(slug: "barberia-centro", slot_interval_minutes: 30)
    end

    it "is where the panel's settings link leads" do
      get admin_root_path(business)

      expect(response.body).to include(%(href="#{edit_admin_business_path(business)}"))
    end
  end

  it "is only for the owner" do
    sign_in_with_role(:admin)

    get edit_admin_business_path(business)
    expect(response).to redirect_to(admin_root_path(business))

    patch admin_business_path(business), params: { business: details }
    expect(business.reload.name).to eq("Barbería Centro")
  end
end
