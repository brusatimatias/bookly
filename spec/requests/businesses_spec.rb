require "rails_helper"

RSpec.describe "Businesses", type: :request do
  describe "the public page, on the business's subdomain" do
    it "renders the public page of the business" do
      business = create(:business, slug: "barberia-centro", name: "Barbería Centro", address: "Av. Corrientes 1234", contact_email: "hola@centro.example")

      host! "barberia-centro.example.com"
      get business_path

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

      use_business_host(business)
      get business_path

      expect(response.body).to include("Corte de pelo", "1 h 30 min", "$ 12.000", "Lavado incluido", "Sofía Torres")
      expect(response.body).not_to include("Coloración", "Barba sin profesionales", "Uñas sin horario", "Pablo sin servicios", "Ana inactiva", "Juan sin horario")
    end

    it "explains when there are no services yet" do
      use_business_host(create(:business))
      get business_path

      expect(response.body).to include("Todavía no hay servicios publicados.")
    end

    it "renders in the business locale" do
      spanish = create(:business, locale: "es")
      english = create(:business, locale: "en")

      use_business_host(spanish)
      get business_path
      expect(response.body).to include('lang="es"', "Todavía no hay servicios publicados.")

      use_business_host(english)
      get business_path
      expect(response.body).to include('lang="en"', "No services published yet.")
    end

    it "responds not found for an unknown subdomain" do
      host! "unknown.example.com"
      get business_path

      expect(response).to have_http_status(:not_found)
    end

    it "shows a suspended business as unavailable, without its details" do
      business = create(:business, :suspended, name: "Barbería Centro", contact_email: "hola@centro.example")

      use_business_host(business)
      get business_path

      expect(response).to have_http_status(:service_unavailable)
      expect(response.body).to include("Este negocio no está disponible en este momento.")
      expect(response.body).not_to include("Barbería Centro", "hola@centro.example")
    end

    it "shows the unavailable page in the business locale" do
      business = create(:business, :suspended, locale: "en")

      use_business_host(business)
      get business_path

      expect(response.body).to include("This business is not available right now.")
    end

    it "does not leak the current business past the request" do
      use_business_host(create(:business))
      get business_path

      expect(Current.business).to be_nil
    end
  end

  describe "the business's brand" do
    let(:business) { create(:business, name: "Barbería Centro", brand_color: "#0f766e") }

    before { use_business_host(business) }

    it "heads the public pages with the business's name and colors them with its color" do
      get business_path

      expect(response.body).to include("--color-brand-600: #0f766e;")
      header = response.body[%r{<header.*?</header>}m]
      expect(header).to include("Barbería Centro")
      expect(header).not_to include("Bookly")
    end

    it "shows its logo in the header and on its page" do
      business.logo.attach(io: file_fixture("photo.png").open, filename: "logo.png", content_type: "image/png")

      get new_booking_path

      expect(response.body.scan(%r{<img[^>]*src="[^"]*/rails/active_storage/[^"]*logo\.png}).size).to eq(1)

      get business_path

      expect(response.body.scan(%r{<img[^>]*src="[^"]*/rails/active_storage/[^"]*logo\.png}).size).to eq(2)
    end

    it "keeps Bookly's without a color" do
      business.update!(brand_color: nil)

      get business_path

      expect(response.body).not_to include("--color-brand-600")
    end

    it "shows nothing of a suspended business" do
      business.suspend!

      get business_path

      expect(response.body).not_to include("--color-brand-600", "Barbería Centro")
    end

    it "stays out of the panel" do
      owner = create(:membership, :owner, business: business).user
      host! "www.example.com"
      sign_in_as(owner)

      get admin_root_path(business)

      expect(response.body).not_to include("--color-brand-600")
    end
  end

  describe "hosts" do
    let!(:business) { create(:business, slug: "barberia-centro") }

    it "serves the app itself on its domain, with or without www" do
      %w[example.com www.example.com].each do |host|
        host! host
        get root_path

        expect(response.body).to include("Tu agenda, siempre en orden")
      end
    end

    it "doesn't serve a business's public pages on the app's domain" do
      get "/appointments/abc"

      expect(response).to have_http_status(:not_found)
    end

    it "doesn't serve the app's pages or the panel on a business's subdomain" do
      host! "barberia-centro.example.com"

      [ new_session_path, new_signup_path, "/barberia-centro/admin" ].each do |path|
        get path
        expect(response).to have_http_status(:not_found)
      end
    end

    it "doesn't treat reserved or nested subdomains as businesses" do
      create(:business, slug: "centro")

      %w[mail.example.com centro.mail.example.com].each do |host|
        host! host
        get "/"
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
