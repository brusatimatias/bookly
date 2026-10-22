require "rails_helper"

RSpec.describe "Admin branding", type: :request do
  let(:business) { create(:business, name: "Barbería Centro") }

  def sign_in_with_role(role)
    user = create(:user)
    create(:membership, business: business, user: user, role: role)
    sign_in_as(user)
  end

  def logo(file = "photo.png", content_type = "image/png")
    fixture_file_upload(file, content_type)
  end

  describe "as the owner" do
    before { sign_in_with_role(:owner) }

    it "shows the logo, the color and a preview, as a settings tab" do
      get edit_admin_branding_path(business)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Marca", "Logo", "Color de marca", "Usar el de Bookly", "Vista previa", "Reservar turno",
                                       %(placeholder="#{BrandColor::DEFAULT}"), edit_admin_business_path(business), edit_admin_settings_path(business))
      expect(response.body).not_to include("Quitar el logo")
    end

    it "saves the logo and the color" do
      patch admin_branding_path(business), params: { business: { brand_color: "#1D4ED8", logo: logo } }

      expect(response).to redirect_to(edit_admin_branding_path(business))
      expect(flash[:notice]).to eq("Guardamos la marca.")
      expect(business.reload.brand_color).to eq("#1d4ed8")
      expect(business.logo).to be_attached

      follow_redirect!
      expect(response.body).to include("Quitar el logo", 'value="#1d4ed8"')
    end

    it "goes back to Bookly's color when the color is left empty" do
      business.update!(brand_color: "#1d4ed8")

      patch admin_branding_path(business), params: { business: { brand_color: "" } }

      expect(business.reload.brand_color).to be_nil
    end

    it "removes the logo, keeping it when a new one comes too" do
      business.logo.attach(logo)

      patch admin_branding_path(business), params: { business: { brand_color: "", remove_logo: "1", logo: logo } }
      expect(business.reload.logo).to be_attached

      patch admin_branding_path(business), params: { business: { brand_color: "", remove_logo: "1" } }
      expect(business.reload.logo).not_to be_attached
    end

    it "shows the errors, keeping what was saved" do
      business.update!(brand_color: "#1d4ed8")

      patch admin_branding_path(business), params: { business: { brand_color: "#fde047", logo: logo("notes.txt", "text/plain") } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("tiene poco contraste con el blanco", "debe ser una imagen JPG, PNG o WebP")
      expect(business.reload.brand_color).to eq("#1d4ed8")
      expect(business.logo).not_to be_attached
    end
  end

  it "is only for the owner" do
    sign_in_with_role(:admin)

    get edit_admin_branding_path(business)
    expect(response).to redirect_to(admin_root_path(business))

    patch admin_branding_path(business), params: { business: { brand_color: "#1d4ed8" } }
    expect(business.reload.brand_color).to be_nil
  end
end
