require "rails_helper"

RSpec.describe "Admin setup assistant", type: :request do
  let(:business) { create(:business, name: "Barbería Centro") }
  let(:owner) { create(:user, name: "Lucía") }

  before do
    create(:membership, :owner, business: business, user: owner)
    sign_in_as(owner)
  end

  def in_business(&block)
    with_business(business, &block)
  end

  it "opens at the business's details for a new business" do
    get admin_setup_path(business)

    expect(response).to redirect_to(admin_setup_step_path(business, "details"))
  end

  it "opens at the first task left" do
    in_business { create(:service) }

    get admin_setup_path(business)

    expect(response).to redirect_to(admin_setup_step_path(business, "professional"))
  end

  describe "details" do
    it "saves the contact details and moves on" do
      get admin_setup_step_path(business, "details")
      expect(response.body).to include("Puesta en marcha", "Datos del negocio", "Omitir")

      patch admin_setup_step_path(business, "details"), params: { business: { name: "Barbería Centro", contact_phone: "+54 11 5555-0101", address: "Av. Corrientes 1234" } }

      expect(response).to redirect_to(admin_setup_step_path(business, "service"))
      expect(business.reload).to have_attributes(contact_phone: "+54 11 5555-0101", address: "Av. Corrientes 1234")
    end

    it "shows the errors" do
      patch admin_setup_step_path(business, "details"), params: { business: { name: "", contact_email: "nope" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Nombre no puede estar en blanco", "Email de contacto no es válido")
      expect(business.reload.name).to eq("Barbería Centro")
    end
  end

  describe "service" do
    it "adds services one at a time, and moves on once there's one" do
      get admin_setup_step_path(business, "service")
      expect(response.body).to include("Tu primer servicio")
      expect(response.body).not_to include("Siguiente")

      patch admin_setup_step_path(business, "service"), params: { service: { name: "Corte", duration_minutes: 30, price: "12000" } }

      expect(response).to redirect_to(admin_setup_step_path(business, "service"))
      expect(in_business { Service.sole }).to have_attributes(name: "Corte", duration_minutes: 30, price_cents: 12_000_00)

      follow_redirect!
      expect(response.body).to include("Agregamos Corte.", "Tus servicios", "Agregar otro servicio", "Siguiente")
    end

    it "shows the errors" do
      patch admin_setup_step_path(business, "service"), params: { service: { name: "", duration_minutes: 0, price: "" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(in_business { Service.count }).to eq(0)
    end
  end

  describe "professional" do
    let!(:service) { in_business { create(:service, name: "Corte") } }

    it "asks for a service first" do
      in_business { service.deactivate! }

      get admin_setup_step_path(business, "professional")

      expect(response.body).to include("Primero cargá un servicio")
    end

    it "makes the owner a professional offering every active service" do
      inactive = in_business { create(:service, :inactive) }

      patch admin_setup_step_path(business, "professional"), params: { myself: 1 }

      expect(response).to redirect_to(admin_setup_step_path(business, "professional"))
      profile = in_business { Professional.sole }
      expect(profile).to have_attributes(user: owner, name: "Lucía")
      expect(in_business { profile.services.to_a }).to eq([ service ])
      expect(in_business { profile.services }).not_to include(inactive)

      follow_redirect!
      expect(response.body).to include("Sumamos a Lucía.", "Siguiente")
      expect(response.body).not_to include("Atiendo yo")
    end

    it "adds someone else by name" do
      patch admin_setup_step_path(business, "professional"), params: { professional: { name: "Ana Torres" } }

      expect(in_business { Professional.sole }).to have_attributes(name: "Ana Torres", user: nil)
      expect(in_business { Professional.sole.services.to_a }).to eq([ service ])
    end

    it "shows the errors" do
      patch admin_setup_step_path(business, "professional"), params: { professional: { name: "" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(in_business { Professional.count }).to eq(0)
    end
  end

  describe "hours" do
    let!(:ana) { in_business { create(:professional, name: "Ana", services: [ create(:service) ]) } }

    it "asks for a professional first" do
      in_business { ana.deactivate! }

      get admin_setup_step_path(business, "hours")

      expect(response.body).to include("Primero sumá a alguien que atienda")
    end

    it "sets the same hours for everyone without them, and finishes" do
      pablo = in_business { create(:professional, :with_hours, name: "Pablo") }

      get admin_setup_step_path(business, "hours")
      expect(response.body).to include("Se cargan para Ana.", "Sin horarios", edit_admin_professional_schedule_path(business, pablo))

      patch admin_setup_step_path(business, "hours"), params: { setup_hours: { days: [ "1", "2" ], start_time: "10:00", end_time: "19:00" } }

      expect(response).to redirect_to(admin_setup_step_path(business, "done"))
      expect(in_business { ana.working_hours.pluck(:day_of_week) }).to contain_exactly(1, 2)
      expect(in_business { pablo.working_hours.count }).to eq(1)
    end

    it "shows the errors" do
      patch admin_setup_step_path(business, "hours"), params: { setup_hours: { days: [ "" ], start_time: "10:00", end_time: "09:00" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Días elegí al menos uno", "Hasta debe ser posterior a la hora de inicio")
    end
  end

  describe "done" do
    it "waits until the business can take bookings" do
      get admin_setup_step_path(business, "done")

      expect(response).to redirect_to(admin_setup_step_path(business, "service"))
    end

    it "shares the public page" do
      in_business { create(:professional, :with_hours, services: [ create(:service) ]) }

      get admin_setup_step_path(business, "done")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("¡Tu página está lista!", business_url(business), admin_team_path(business))
    end
  end

  it "rejects unknown steps" do
    get "/#{business.slug}/admin/setup/nope"

    expect(response).to have_http_status(:not_found)
  end

  it "is only for the owner" do
    admin = create(:user)
    create(:membership, :admin, business: business, user: admin)
    sign_in_as(admin)

    get admin_setup_step_path(business, "service")
    expect(response).to redirect_to(admin_root_path(business))

    patch admin_setup_step_path(business, "service"), params: { service: { name: "Corte", duration_minutes: 30, price: "1" } }
    expect(in_business { Service.count }).to eq(0)
  end
end
