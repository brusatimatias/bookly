require "rails_helper"

RSpec.describe "Admin agenda", type: :request do
  let(:business) { create(:business, time_zone: "America/Argentina/Buenos_Aires") }
  let(:zone) { Time.find_zone!(business.time_zone) }
  let(:service) { in_business { create(:service, name: "Corte") } }
  let(:own_membership) { create(:membership, business: business) }
  let(:martin) { in_business { create(:professional, name: "Martín", user: own_membership.user, services: [ service ]) } }
  let(:sofia) { in_business { create(:professional, name: "Sofía", services: [ service ]) } }

  # Thursday 15 Oct 2026; the week goes from Monday 12 to Sunday 18.
  around { |example| travel_to(Time.find_zone!("America/Argentina/Buenos_Aires").local(2026, 10, 15, 12)) { example.run } }

  def in_business(&block)
    with_business(business, &block)
  end

  def appointment(professional, name, starts_at, status: nil)
    in_business do
      created = build(:appointment, service: service, professional: professional, starts_at: starts_at, customer: create(:customer, name: name))
      created.save!(validate: false)
      created.tap { created.update_columns(status: status) if status }
    end
  end

  before do
    appointment(martin, "Ana Pérez", zone.local(2026, 10, 12, 9), status: "attended")
    appointment(sofia, "Juan Ríos", zone.local(2026, 10, 16, 15), status: "confirmed")
    appointment(martin, "Carla Díaz", zone.local(2026, 10, 17, 10))
    appointment(martin, "Rechazada", zone.local(2026, 10, 17, 11), status: "rejected")
    appointment(martin, "Next Week", zone.local(2026, 10, 19, 10))
  end

  it "shows managers this week's appointments of every professional, by day" do
    sign_in_as(create(:membership, :admin, business: business).user)

    get admin_agenda_path(business)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("lun 12 oct – dom 18 oct", "Ana Pérez", "Juan Ríos", "Carla Díaz", "Sofía", "Hoy")
    expect(response.body).not_to include("Rechazada", "Next Week")
    friday = response.body[/id="day-2026-10-16".*?<\/li>\s*<\/ul>/m]
    expect(friday).to include("15:00", "Juan Ríos")
  end

  it "filters by professional and keeps the filter when moving between weeks" do
    sign_in_as(create(:membership, :owner, business: business).user)

    get admin_agenda_path(business, professional_id: martin.id)

    expect(response.body).to include("Ana Pérez", "Carla Díaz")
    expect(response.body).not_to include("Juan Ríos")
    expect(response.body).to include(CGI.escapeHTML(admin_agenda_path(business, week: "2026-10-19", professional_id: martin.id)))
  end

  it "shows another week, from any date in it" do
    sign_in_as(create(:membership, :owner, business: business).user)

    get admin_agenda_path(business, week: "2026-10-21")

    expect(response.body).to include("lun 19 oct – dom 25 oct", "Next Week")
    expect(response.body).not_to include("Ana Pérez")
  end

  it "falls back to this week for an invalid date" do
    sign_in_as(create(:membership, :owner, business: business).user)

    get admin_agenda_path(business, week: "nope")

    expect(response.body).to include("lun 12 oct – dom 18 oct")
  end

  it "shows professionals only their own appointments, without the filter" do
    sign_in_as(own_membership.user)

    get admin_agenda_path(business, professional_id: sofia.id)

    expect(response.body).to include("Tus turnos", "Ana Pérez", "Carla Díaz")
    expect(response.body).not_to include("Juan Ríos", 'name="professional_id"')
  end

  it "tells professionals without a profile" do
    sign_in_as(create(:membership, business: business).user)

    get admin_agenda_path(business)

    expect(response.body).to include("No tenés un perfil de profesional.")
    expect(response.body).not_to include("Ana Pérez")
  end

  it "shows nothing from other businesses" do
    with_business(create(:business)) { create(:appointment, starts_at: zone.local(2026, 10, 16, 10), customer: create(:customer, name: "Foreign")) }
    sign_in_as(create(:membership, :owner, business: business).user)

    get admin_agenda_path(business)

    expect(response.body).not_to include("Foreign")
  end
end
