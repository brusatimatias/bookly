require "rails_helper"

RSpec.describe "Admin professionals", type: :request do
  let(:business) { create(:business) }

  def member(role, **user_attributes)
    create(:membership, business: business, role: role, user: create(:user, **user_attributes)).user
  end

  def in_business(&block)
    with_business(business, &block)
  end

  def professionals_count
    in_business { Professional.count }
  end

  describe "as a manager" do
    let(:manager) { member(:admin) }

    before { sign_in_as(manager) }

    it "lists professionals with their account, services and status" do
      in_business do
        haircut = create(:service, name: "Corte de pelo")
        create(:professional, name: "Sofía Torres", services: [ haircut ])
        create(:professional, name: "Pablo Paz")
        create(:professional, :inactive, name: "Ana Ruiz")
      end

      get admin_professionals_path(business)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sofía Torres", "Sin cuenta vinculada", "Corte de pelo", "Sin servicios", "Inactivo", "Nuevo profesional")
      expect(response.body.index("Sofía Torres")).to be < response.body.index("Ana Ruiz")
    end

    it "shows an empty state" do
      get admin_professionals_path(business)

      expect(response.body).to include("Todavía no hay profesionales.", new_admin_professional_path(business))
    end

    it "offers the active services and the members without a profile" do
      in_business do
        create(:service, name: "Corte de pelo")
        create(:service, :inactive, name: "Coloración")
        create(:professional, user: member(:professional, name: "Martín Gómez"))
      end
      member(:professional, name: "Diego Ruiz")

      get new_admin_professional_path(business)

      expect(response.body).to include("Corte de pelo", "Diego Ruiz")
      expect(response.body).not_to include("Coloración", "Martín Gómez")
    end

    it "links the form to services when there are none" do
      get new_admin_professional_path(business)

      expect(response.body).to include("Todavía no hay servicios.", new_admin_service_path(business))
    end

    it "creates a professional with a photo and services" do
      services = in_business { create_list(:service, 2) }

      expect {
        post admin_professionals_path(business), params: { professional: {
          name: "Sofía Torres", user_id: "", service_ids: [ "", *services.map(&:id) ],
          photo: fixture_file_upload("photo.png", "image/png")
        } }
      }.to change { professionals_count }.by(1)

      professional = in_business { Professional.last }
      expect(professional).to have_attributes(name: "Sofía Torres", user: nil)
      expect(professional.photo).to be_attached
      expect(in_business { professional.services.to_a }).to match_array(services)
      expect(response).to redirect_to(admin_professionals_path(business))
    end

    it "creates a profile for a member, taking their name" do
      user = member(:professional, name: "Martín Gómez")

      post admin_professionals_path(business), params: { professional: { name: "", user_id: user.id } }

      expect(in_business { Professional.last }).to have_attributes(name: "Martín Gómez", user: user)
    end

    it "lets managers add themselves as professionals" do
      post admin_professionals_path(business), params: { professional: { name: "", user_id: manager.id } }

      expect(in_business { Professional.last.user }).to eq(manager)
    end

    it "shows errors for an invalid professional" do
      post admin_professionals_path(business), params: { professional: { name: "", photo: fixture_file_upload("notes.txt", "text/plain") } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Nombre no puede estar en blanco", "Foto debe ser una imagen JPG, PNG o WebP")
    end

    it "rejects linking someone outside the business" do
      outsider = create(:membership).user

      post admin_professionals_path(business), params: { professional: { name: "Intruso", user_id: outsider.id } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Miembro no es miembro de este negocio")
    end

    it "cannot assign services of another business" do
      other_service = with_business(create(:business)) { create(:service) }

      post admin_professionals_path(business), params: { professional: { name: "Sofía", service_ids: [ other_service.id ] } }

      expect(response).to have_http_status(:not_found)
      expect(professionals_count).to eq(0)
    end

    it "updates the services, keeping the form's inactive ones" do
      professional, inactive_service = in_business do
        inactive = create(:service, :inactive, name: "Coloración")
        [ create(:professional, services: [ inactive, create(:service) ]), inactive ]
      end

      get edit_admin_professional_path(business, professional)
      expect(response.body).to include("Coloración")

      patch admin_professional_path(business, professional), params: { professional: { service_ids: [ "", inactive_service.id ] } }

      expect(in_business { professional.reload.services.to_a }).to eq([ inactive_service ])
      expect(response).to redirect_to(admin_professionals_path(business))
    end

    it "removes every service" do
      professional = in_business { create(:professional, services: [ create(:service) ]) }

      patch admin_professional_path(business, professional), params: { professional: { service_ids: [ "" ] } }

      expect(in_business { professional.reload.services.to_a }).to be_empty
    end

    it "shows errors when updating" do
      professional = in_business { create(:professional, name: "Sofía") }

      patch admin_professional_path(business, professional), params: { professional: { name: " " } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Editar Sofía", "Nombre no puede estar en blanco")
    end

    it "deactivates and reactivates a professional" do
      professional = in_business { create(:professional) }

      patch deactivate_admin_professional_path(business, professional)
      expect(professional.reload).not_to be_active
      expect(response).to redirect_to(admin_professionals_path(business))

      patch reactivate_admin_professional_path(business, professional)
      expect(professional.reload).to be_active
    end

    it "cannot touch professionals of another business" do
      other = with_business(create(:business)) { create(:professional) }

      get edit_admin_professional_path(business, other)
      expect(response).to have_http_status(:not_found)

      patch deactivate_admin_professional_path(business, other)
      expect(response).to have_http_status(:not_found)
      expect(other.reload).to be_active
    end
  end

  describe "as a professional" do
    let(:user) { member(:professional) }

    before { sign_in_as(user) }

    it "lists the professionals without management actions, marking their own profile" do
      professional = in_business { create(:professional, user: user) }

      get admin_professionals_path(business)

      expect(response.body).to include(professional.name, "(vos)")
      expect(response.body).not_to include("Nuevo profesional", edit_admin_professional_path(business, professional))
    end

    it "cannot create, edit or deactivate professionals" do
      professional = in_business { create(:professional) }

      get edit_admin_professional_path(business, professional)
      expect(response).to redirect_to(admin_root_path(business))

      expect { post admin_professionals_path(business), params: { professional: { name: "Otro" } } }
        .not_to change { professionals_count }

      patch deactivate_admin_professional_path(business, professional)
      expect(professional.reload).to be_active
    end
  end
end
