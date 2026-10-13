require "rails_helper"

RSpec.describe "Layouts", type: :request do
  let(:business) { create(:business, name: "Barbería Centro") }

  describe "public layout" do
    it "has the header with sign in link and the footer" do
      get root_path

      expect(response.body).to include("Iniciar sesión", "Reservas de turnos online")
    end

    it "credits Bookly on business pages, without sign in link" do
      get business_path(business)

      expect(response.body).to include("Reservas online con Bookly")
      expect(response.body).not_to include(new_session_path)
    end
  end

  describe "auth layout" do
    it "wraps the sign in form in a card with the language switcher" do
      get new_session_path

      expect(response.body).to include('class="card', "English")
      expect(response.body).not_to include("<footer")
    end
  end

  describe "admin layout" do
    def sign_in_with_role(role)
      user = create(:user, name: "Lucía Fernández")
      create(:membership, business: business, user: user, role: role)
      sign_in_as(user)
    end

    it "shows the business, the role, the user and the navigation" do
      sign_in_with_role(:owner)

      get admin_root_path(business)

      expect(response.body).to include("Barbería Centro", "Dueño", "Lucía Fernández", "LF", "Inicio", "Servicios", "Profesionales", "Bloqueos", "Equipo", "Página pública")
      expect(response.body).to include('data-controller="sidebar"')
    end

    it "highlights the current section" do
      sign_in_with_role(:owner)

      get admin_team_path(business)

      expect(response.body).to match(/<a[^>]*aria-current="page"[^>]*href="#{admin_team_path(business)}"|<a[^>]*href="#{admin_team_path(business)}"[^>]*aria-current="page"/)
    end

    it "keeps professionals highlighted while editing a professional's hours" do
      sign_in_with_role(:owner)
      professional = with_business(business) { create(:professional) }

      get edit_admin_professional_schedule_path(business, professional)

      expect(response.body).to match(/<a[^>]*aria-current="page"[^>]*href="#{admin_professionals_path(business)}"|<a[^>]*href="#{admin_professionals_path(business)}"[^>]*aria-current="page"/)
    end

    it "hides the team section from professionals, but not services, professionals and blocks" do
      sign_in_with_role(:professional)

      get admin_root_path(business)

      expect(response.body).not_to include(admin_team_path(business))
      expect(response.body).to include(admin_services_path(business), admin_professionals_path(business), admin_time_blocks_path(business))
    end
  end
end
