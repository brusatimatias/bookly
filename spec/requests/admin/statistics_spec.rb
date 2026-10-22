require "rails_helper"

RSpec.describe "Admin statistics", type: :request do
  let(:business) { create(:business, time_zone: "America/Argentina/Buenos_Aires") }
  let(:zone) { Time.find_zone!(business.time_zone) }
  let(:haircut) { in_business { create(:service, name: "Corte", price_cents: 10_000_00) } }
  let(:beard) { in_business { create(:service, name: "Barba", price_cents: 4_000_00) } }
  let(:own_membership) { create(:membership, business: business) }
  let(:martin) { in_business { create(:professional, name: "Martín", user: own_membership.user, services: [ haircut, beard ]) } }
  let(:sofia) { in_business { create(:professional, name: "Sofía", services: [ haircut, beard ]) } }

  # Wednesday 21 Oct 2026.
  around { |example| travel_to(Time.find_zone!("America/Argentina/Buenos_Aires").local(2026, 10, 21, 12)) { example.run } }

  def in_business(&block)
    with_business(business, &block)
  end

  def appointment(professional, service, starts_at, status)
    in_business { create(:appointment, professional: professional, service: service, starts_at: starts_at, status: status) }
  end

  before do
    appointment(martin, haircut, zone.local(2026, 10, 5, 10), :attended)
    appointment(martin, beard, zone.local(2026, 10, 6, 10), :no_show)
    appointment(sofia, beard, zone.local(2026, 10, 7, 15), :attended)
    appointment(sofia, haircut, zone.local(2026, 9, 14, 10), :attended)
  end

  it "shows managers the whole business this month" do
    sign_in_as(create(:membership, :admin, business: business).user)

    get admin_statistics_path(business)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Del 1 de octubre al 31 de octubre", "Actualizado hace", "$ 14.000", "Corte", "Barba", "Martín", "Sofía")
    expect(response.body[/id="outcomes".*?<\/section>/m]).to include("3 turnos que empiezan en el período")
    expect(response.body).to include("1 turno sin asistencia")
    expect(response.body).to match(/aria-current="page"[^>]*>Este mes/)
  end

  it "shows another period" do
    sign_in_as(create(:membership, :owner, business: business).user)

    get admin_statistics_path(business, period: "last_month")

    expect(response.body).to include("Del 1 de septiembre al 30 de septiembre", "$ 10.000")
    expect(response.body).to match(/aria-current="page"[^>]*>El mes pasado/)
  end

  it "falls back to this month for an unknown period" do
    sign_in_as(create(:membership, :owner, business: business).user)

    get admin_statistics_path(business, period: "forever")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Del 1 de octubre al 31 de octubre")
  end

  it "shows professionals their own numbers only" do
    sign_in_as(own_membership.user)

    get admin_statistics_path(business)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Cómo te va", "$ 10.000", "Martín")
    expect(response.body).not_to include("Sofía")
  end

  it "tells a professional without a profile that there's nothing to show" do
    sign_in_as(create(:membership, business: business).user)

    get admin_statistics_path(business)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No tenés un perfil de profesional")
  end

  it "says when there's no data yet" do
    in_business { Appointment.delete_all }
    sign_in_as(create(:membership, :owner, business: business).user)

    get admin_statistics_path(business)

    expect(response.body).to include("Todavía no hay datos en este período.")
  end

  it "is in the business's language" do
    business.update!(locale: "en")
    sign_in_as(create(:membership, :owner, business: business).user)

    get admin_statistics_path(business)

    expect(response.body).to include("Statistics", "From October 1 to October 31", "3 appointments starting in the period", "1 appointment missed")
  end

  it "is only for the business's members" do
    sign_in_as(create(:membership, :owner).user)

    get admin_statistics_path(business)

    expect(response).to have_http_status(:not_found)
  end
end
