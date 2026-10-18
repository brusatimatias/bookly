require "rails_helper"

RSpec.describe "Businesses", type: :request do
  describe "GET /:business_slug" do
    it "renders the public page of the business" do
      business = create(:business, name: "Barbería Centro", address: "Av. Corrientes 1234", contact_email: "hola@centro.example")

      get business_path(business)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Barbería Centro", "Av. Corrientes 1234", "hola@centro.example")
    end

    it "shows the services and professionals customers can book" do
      business = create(:business)
      with_business(business) do
        haircut = create(:service, name: "Corte de pelo", duration_minutes: 90, price_cents: 1_200_000, description: "Lavado incluido")
        create(:service, :inactive, name: "Coloración")
        create(:service, name: "Barba sin profesionales")
        nails = create(:service, name: "Uñas sin horario")
        create(:professional, :with_hours, name: "Sofía Torres", services: [ haircut ])
        create(:professional, :with_hours, name: "Pablo sin servicios")
        create(:professional, :inactive, :with_hours, name: "Ana inactiva", services: [ haircut ])
        create(:professional, name: "Juan sin horario", services: [ haircut, nails ])
      end

      get business_path(business)

      expect(response.body).to include("Corte de pelo", "1 h 30 min", "$ 12.000", "Lavado incluido", "Sofía Torres")
      expect(response.body).not_to include("Coloración", "Barba sin profesionales", "Uñas sin horario", "Pablo sin servicios", "Ana inactiva", "Juan sin horario")
    end

    it "explains when there are no services yet" do
      get business_path(create(:business))

      expect(response.body).to include("Todavía no hay servicios publicados.")
    end

    it "renders in the business locale" do
      spanish = create(:business, locale: "es")
      english = create(:business, locale: "en")

      get business_path(spanish)
      expect(response.body).to include('lang="es"', "Todavía no hay servicios publicados.")

      get business_path(english)
      expect(response.body).to include('lang="en"', "No services published yet.")
    end

    it "responds not found for an unknown slug" do
      get business_path("unknown")

      expect(response).to have_http_status(:not_found)
    end

    it "shows a suspended business as unavailable, without its details" do
      business = create(:business, :suspended, name: "Barbería Centro", contact_email: "hola@centro.example")

      get business_path(business)

      expect(response).to have_http_status(:service_unavailable)
      expect(response.body).to include("Este negocio no está disponible en este momento.")
      expect(response.body).not_to include("Barbería Centro", "hola@centro.example")
    end

    it "shows the unavailable page in the business locale" do
      business = create(:business, :suspended, locale: "en")

      get business_path(business)

      expect(response.body).to include("This business is not available right now.")
    end

    it "does not leak the current business past the request" do
      get business_path(create(:business))

      expect(Current.business).to be_nil
    end
  end
end
