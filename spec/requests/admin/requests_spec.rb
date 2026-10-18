require "rails_helper"

RSpec.describe "Admin requests", type: :request do
  let(:business) { create(:business, request_expiration_hours: 24) }
  let(:service) { in_business { create(:service, name: "Corte") } }
  let(:own_membership) { create(:membership, business: business) }
  let(:own_profile) { in_business { create(:professional, name: "Martín", user: own_membership.user, services: [ service ]) } }
  let(:other_profile) { in_business { create(:professional, name: "Sofía", services: [ service ]) } }

  def in_business(&block)
    with_business(business, &block)
  end

  def request_for(professional, name, starts_at)
    in_business { create(:appointment, service: service, professional: professional, starts_at: starts_at, customer: create(:customer, name: name)) }
  end

  before do
    request_for(own_profile, "Ana Pérez", 3.days.from_now)
    request_for(other_profile, "Juan Ríos", 2.hours.from_now)
    in_business { create(:appointment, :confirmed, service: service, professional: own_profile, customer: create(:customer, name: "Carla Díaz")) }
  end

  it "lists every pending request to managers, the ones expiring first on top, with the sidebar count" do
    sign_in_as(create(:membership, :admin, business: business).user)

    get admin_requests_path(business)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Ana Pérez", "Juan Ríos", "Confirmar", "Rechazar")
    expect(response.body.index("Juan Ríos")).to be < response.body.index("Ana Pérez")
    expect(response.body).not_to include("Carla Díaz")
    expect(response.body).to match(%r{Pedidos\s*<span class="badge-yellow ml-auto">2</span>})
  end

  it "says which requests are a change of time, and the time they had" do
    ana = in_business { Appointment.joins(:customer).find_by!(customers: { name: "Ana Pérez" }) }
    in_business { create(:appointment_event, :reschedule, appointment: ana, from: ana.starts_at - 1.day) }
    sign_in_as(create(:membership, :admin, business: business).user)

    get admin_requests_path(business)

    expect(response.body.scan("Cambio de horario · antes").size).to eq(1)
    expect(response.body).to include("Cambio de horario · antes #{I18n.l(ana.starts_at.in_time_zone(business.time_zone) - 1.day, format: :weekday_hour, locale: :es)}")
  end

  it "shows professionals only their own requests" do
    sign_in_as(own_membership.user)

    get admin_requests_path(business)

    expect(response.body).to include("Ana Pérez").and(include("Tus pedidos"))
    expect(response.body).not_to include("Juan Ríos")
  end

  it "leaves out requests whose deadline passed" do
    sign_in_as(create(:membership, :owner, business: business).user)

    travel_to(25.hours.from_now) { get admin_requests_path(business) }

    expect(response.body).to include("No hay pedidos pendientes.")
    expect(response.body).not_to include("Ana Pérez")
  end

  it "shows nothing from other businesses" do
    other = create(:business)
    with_business(other) { create(:appointment, customer: create(:customer, name: "Foreign Customer")) }
    sign_in_as(create(:membership, :owner, business: business).user)

    get admin_requests_path(business)

    expect(response.body).not_to include("Foreign Customer")
  end
end
