require "rails_helper"

RSpec.describe "Platform businesses", type: :request do
  let(:platform_admin) { create(:user, platform_admin: true) }
  let(:centro) { create(:business, name: "Barbería Centro", created_at: 2.days.ago) }
  let(:studio) { create(:business, name: "Downtown Studio", created_at: 1.day.ago) }

  def with_owner(business, email)
    create(:membership, :owner, business: business, user: create(:user, email_address: email))
    business
  end

  describe "for platform admins" do
    before { sign_in_as(platform_admin) }

    it "lists every business, newest first, with its owner and numbers" do
      with_owner(centro, "lucia@centro.example")
      with_owner(studio, "sam@studio.example")
      create(:membership, business: centro)
      with_business(centro) { create(:appointment) }

      get platform_businesses_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lucia@centro.example", "sam@studio.example")
      expect(response.body.index("Downtown Studio")).to be < response.body.index("Barbería Centro")
      expect(response.body).to match(%r{Miembros</dt>\s*<dd[^>]*>2</dd>})
      expect(response.body).to match(%r{Turnos \(30 días\)</dt>\s*<dd[^>]*>1</dd>})
    end

    it "is the platform's home, linked from the header" do
      get platform_root_path
      expect(response).to have_http_status(:ok)

      get root_path
      expect(response.body).to include(%(href="#{platform_root_path}"))
    end

    it "searches by name, web address or owner's email" do
      with_owner(centro, "lucia@centro.example")
      with_owner(studio, "sam@studio.example")

      get platform_businesses_path(q: "LUCIA@")
      expect(response.body).to include("Barbería Centro")
      expect(response.body).not_to include("Downtown Studio")

      get platform_businesses_path(q: "downtown-")
      expect(response.body).to include("Downtown Studio")
      expect(response.body).not_to include("Barbería Centro")

      get platform_businesses_path(q: "100%")
      expect(response.body).to include("No hay negocios.")
    end

    it "filters by status" do
      centro.suspend!
      studio

      get platform_businesses_path(status: "suspended")

      expect(response.body).to include("Barbería Centro")
      expect(response.body).not_to include("Downtown Studio")
    end

    it "pages through the businesses" do
      stub_const("Platform::BusinessesController::PER_PAGE", 1)
      centro
      studio

      get platform_businesses_path
      expect(response.body).to include("Downtown Studio", platform_businesses_path(page: 2))
      expect(response.body).not_to include("Barbería Centro")

      get platform_businesses_path(page: 2)
      expect(response.body).to include("Barbería Centro", "Anterior")
      expect(response.body).not_to include("Downtown Studio")
    end

    it "shows a business's details, team and numbers" do
      with_owner(centro, "lucia@centro.example")
      create(:membership, :admin, business: centro, user: create(:user, email_address: "diego@centro.example"))
      with_business(centro) { create(:professional, :with_hours, services: [ create(:service) ]) }

      get platform_business_path(centro)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Barbería Centro", "/barberia-centro", "Recibe turnos", "Equipo (2)", "Suspender")
      expect(response.body.index("lucia@centro.example")).to be < response.body.index("diego@centro.example")
      expect(response.body).to match(%r{Profesionales reservables</p>\s*<p[^>]*>1</p>})
    end

    it "suspends and reactivates a business" do
      patch suspend_platform_business_path(centro)

      expect(response).to redirect_to(platform_business_path(centro))
      expect(flash[:notice]).to eq("Suspendimos Barbería Centro.")
      expect(centro.reload).to be_suspended

      get business_path(centro)
      expect(response).to have_http_status(:service_unavailable)

      patch reactivate_platform_business_path(centro)

      expect(centro.reload).to be_active
      expect(centro.suspended_at).to be_nil
    end

    it "responds not found for an unknown business" do
      get platform_business_path("unknown")

      expect(response).to have_http_status(:not_found)
    end
  end

  it "is hidden from everyone else" do
    user = create(:user)
    create(:membership, :owner, business: centro, user: user)
    sign_in_as(user)

    get platform_businesses_path
    expect(response).to have_http_status(:not_found)

    patch suspend_platform_business_path(centro)
    expect(response).to have_http_status(:not_found)
    expect(centro.reload).to be_active

    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(platform_root_path)
  end

  it "requires signing in" do
    get platform_businesses_path

    expect(response).to redirect_to(new_session_path)
  end
end
