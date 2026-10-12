require "rails_helper"

RSpec.describe "Admin services", type: :request do
  let(:business) { create(:business) }

  def member(role)
    create(:membership, business: business, role: role).user
  end

  def create_service(**attributes)
    with_business(business) { create(:service, **attributes) }
  end

  let(:valid_params) do
    { service: { name: "Corte de pelo", duration_minutes: "30", price: "12000.50", buffer_minutes: "", description: "<p>Lavado incluido</p>" } }
  end

  describe "as a manager" do
    before { sign_in_as(member(:admin)) }

    it "lists active services first, then inactive ones" do
      create_service(name: "Barba", price_cents: 800_000)
      create_service(name: "Afeitado", active: false)

      get admin_services_path(business)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Barba", "$ 8.000", "Inactivo", "Nuevo servicio")
      expect(response.body.index("Barba")).to be < response.body.index("Afeitado")
    end

    it "flags active services nobody offers" do
      create_service(name: "Barba")

      get admin_services_path(business)

      expect(response.body).to include("Sin profesionales")
    end

    it "shows an empty state" do
      get admin_services_path(business)

      expect(response.body).to include("Todavía no hay servicios.", new_admin_service_path(business))
    end

    it "renders the form" do
      get new_admin_service_path(business)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Precio (ARS)", "trix-editor")
    end

    it "creates a service" do
      expect { post admin_services_path(business), params: valid_params }
        .to change { with_business(business) { Service.count } }.by(1)

      service = with_business(business) { Service.last }
      expect(service).to have_attributes(name: "Corte de pelo", duration_minutes: 30, price_cents: 1_200_050, buffer_minutes: nil)
      expect(service.description.to_plain_text).to eq("Lavado incluido")
      expect(response).to redirect_to(admin_services_path(business))
    end

    it "shows errors for an invalid service" do
      post admin_services_path(business), params: { service: valid_params[:service].merge(name: "", duration_minutes: "0") }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Nombre no puede estar en blanco", "Duración debe ser mayor que 0")
    end

    it "updates a service" do
      service = create_service(name: "Corte")

      patch admin_service_path(business, service), params: { service: { name: "Corte clásico", price: "9000" } }

      expect(service.reload).to have_attributes(name: "Corte clásico", price_cents: 900_000)
      expect(response).to redirect_to(admin_services_path(business))
    end

    it "shows errors when updating" do
      create_service(name: "Barba")
      service = create_service(name: "Corte")

      patch admin_service_path(business, service), params: { service: { name: "barba" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Editar Corte", "Nombre ya está en uso")
    end

    it "deactivates and reactivates a service" do
      service = create_service

      patch deactivate_admin_service_path(business, service)
      expect(service.reload).not_to be_active
      expect(response).to redirect_to(admin_services_path(business))

      patch reactivate_admin_service_path(business, service)
      expect(service.reload).to be_active
    end

    it "cannot touch services of another business" do
      other_service = with_business(create(:business)) { create(:service) }

      get edit_admin_service_path(business, other_service)
      expect(response).to have_http_status(:not_found)

      patch deactivate_admin_service_path(business, other_service)
      expect(response).to have_http_status(:not_found)
      expect(other_service.reload).to be_active
    end
  end

  it "lets the owner manage services" do
    sign_in_as(member(:owner))

    expect { post admin_services_path(business), params: valid_params }
      .to change { with_business(business) { Service.count } }.by(1)
  end

  describe "as a professional" do
    before { sign_in_as(member(:professional)) }

    it "lists the services without management actions" do
      service = create_service(name: "Barba")

      get admin_services_path(business)

      expect(response.body).to include("Barba")
      expect(response.body).not_to include("Nuevo servicio", edit_admin_service_path(business, service))
    end

    it "explains the empty list without offering to create" do
      get admin_services_path(business)

      expect(response.body).to include("Cuando el negocio cargue sus servicios")
      expect(response.body).not_to include(new_admin_service_path(business))
    end

    it "cannot create, edit or deactivate services" do
      service = create_service

      get new_admin_service_path(business)
      expect(response).to redirect_to(admin_root_path(business))

      expect { post admin_services_path(business), params: valid_params }
        .not_to change { with_business(business) { Service.count } }

      patch deactivate_admin_service_path(business, service)
      expect(service.reload).to be_active
    end
  end
end
