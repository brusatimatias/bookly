require "rails_helper"

RSpec.describe "Admin dashboard", type: :request do
  let(:business) { create(:business, name: "Barbería Centro") }
  let(:user) { create(:user, name: "Lucía") }

  it "asks to sign in and then returns to the panel" do
    create(:membership, :owner, business: business, user: user)

    get admin_root_path(business)
    expect(response).to redirect_to(new_session_path)

    sign_in_as(user)
    expect(response).to redirect_to(admin_root_url(business))
  end

  it "shows the panel to members, in the business locale" do
    business.update!(locale: "en")
    create(:membership, :admin, business: business, user: user)
    sign_in_as(user)

    get admin_root_path(business)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('lang="en"', "Barbería Centro", "Hi, Lucía", "Admin")
  end

  it "responds not found to users who are not members" do
    create(:membership, :owner, business: create(:business), user: user)
    sign_in_as(user)

    get admin_root_path(business)

    expect(response).to have_http_status(:not_found)
  end

  it "responds not found for an unknown business" do
    sign_in_as(user)

    get admin_root_path(business_slug: "unknown")

    expect(response).to have_http_status(:not_found)
  end

  it "shows the unavailable page when the business is suspended" do
    create(:membership, :owner, business: business, user: user)
    business.suspend!
    sign_in_as(user)

    get admin_root_path(business)

    expect(response).to have_http_status(:service_unavailable)
  end

  describe "requests and today's appointments" do
    it "shows the member's pending requests and today's appointments" do
      travel_to(Time.find_zone!(business.time_zone).local(2026, 10, 19, 12))
      membership = create(:membership, business: business, user: user)
      with_business(business) do
        service = create(:service, name: "Corte")
        profile = create(:professional, user: user, services: [ service ])
        create(:appointment, service: service, professional: profile, starts_at: 3.days.from_now, customer: create(:customer, name: "Ana Pérez"))
        create(:appointment, :confirmed, service: service, professional: profile, starts_at: 1.hour.from_now, customer: create(:customer, name: "Juan Ríos"))
        create(:appointment, starts_at: 1.hour.from_now, customer: create(:customer, name: "Someone Else's"))
      end
      sign_in_as(membership.user)

      get admin_root_path(business)

      expect(response.body).to include("Pedidos pendientes", "Ana Pérez", "Turnos de hoy", "Juan Ríos")
      expect(response.body).not_to include("Someone Else")
    end

    it "says when there is nothing" do
      create(:membership, :owner, business: business, user: user)
      sign_in_as(user)

      get admin_root_path(business)

      expect(response.body).to include("No hay pedidos esperando respuesta.", "No hay turnos para hoy.")
    end
  end

  describe "team summary" do
    before do
      create(:membership, :owner, business: business, user: user)
      create(:membership, business: business)
      create(:invitation, business: business, invited_by: user)
      with_business(business) do
        create(:service)
        create(:service, :inactive)
        create(:professional)
        create(:professional, :inactive)
      end
    end

    it "shows managers the team, invitation, service and professional counts" do
      sign_in_as(user)

      get admin_root_path(business)

      expect(response.body).to match(%r{Miembros del equipo</p>\s*<p[^>]*>2</p>})
      expect(response.body).to match(%r{Invitaciones pendientes</p>\s*<p[^>]*>1</p>})
      expect(response.body).to match(%r{Servicios activos</p>\s*<p[^>]*>1</p>})
      expect(response.body).to match(%r{Profesionales activos</p>\s*<p[^>]*>1</p>})
    end

    it "is hidden from professionals" do
      professional = business.memberships.professional.first.user
      sign_in_as(professional)

      get admin_root_path(business)

      expect(response.body).not_to include("Miembros del equipo")
    end
  end
end
