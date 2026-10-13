require "rails_helper"

RSpec.describe "Admin availability", type: :request do
  let(:business) do
    create(:business, time_zone: "America/Argentina/Buenos_Aires", min_booking_notice_hours: 0, booking_horizon_days: 30)
  end
  let(:zone) { Time.find_zone!(business.time_zone) }
  # A Wednesday morning.
  let(:now) { zone.local(2026, 10, 14, 8) }
  let(:service) { in_business { create(:service, name: "Corte de pelo", duration_minutes: 30) } }
  let(:martin) { in_business { create(:professional, name: "Martín Gómez", services: [ service ]) } }
  let(:sofia) { in_business { create(:professional, name: "Sofía Torres", services: [ service ]) } }

  around { |example| travel_to(now) { example.run } }

  def in_business(&block)
    with_business(business, &block)
  end

  def member(role)
    create(:membership, business: business, role: role).user
  end

  def works(professional, day_of_week, start_time, end_time)
    in_business { create(:working_hour, professional: professional, day_of_week: day_of_week, start_time: start_time, end_time: end_time) }
  end

  describe "as a manager" do
    before do
      works(martin, 4, "09:00", "10:00")
      works(sofia, 5, "15:00", "16:00")
      sign_in_as(member(:admin))
    end

    it "shows this week's free times of any professional, explaining the days without them" do
      get admin_availability_path(business)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Corte de pelo", "Cualquiera", "lun 12 oct – dom 18 oct", "Hora de Buenos Aires")
      expect(response.body).to include("09:00", "09:30", "15:00", "15:30", "Ya pasó", "No se atiende")
      expect(response.body).to include('title="Martín Gómez"')
    end

    it "shows one professional's free times" do
      get admin_availability_path(business, service_id: service.id, professional_id: sofia.id)

      expect(response.body).to include("15:00")
      expect(response.body).not_to include("09:30")
    end

    it "explains the days already taken" do
      in_business do
        create(:time_block, professional: martin, starts_at: zone.local(2026, 10, 15, 9), ends_at: zone.local(2026, 10, 15, 10))
      end

      get admin_availability_path(business, service_id: service.id, professional_id: martin.id)

      expect(response.body).to include("Sin horarios libres")
    end

    it "moves between weeks within the booking window" do
      get admin_availability_path(business, week: "2026-10-21")
      expect(response.body).to include("lun 19 oct – dom 25 oct")

      get admin_availability_path(business, week: "2027-06-01")
      expect(response.body).to include("lun 9 nov – dom 15 nov", "Fuera del plazo de reserva")

      get admin_availability_path(business, week: "2020-01-01")
      expect(response.body).to include("lun 12 oct – dom 18 oct")

      get admin_availability_path(business, week: "nonsense")
      expect(response.body).to include("lun 12 oct – dom 18 oct")
    end

    it "points to the next free day when the week has none" do
      in_business do
        create(:time_block, professional: martin, starts_at: zone.local(2026, 10, 15, 0), ends_at: zone.local(2026, 10, 16, 0))
        create(:time_block, professional: sofia, starts_at: zone.local(2026, 10, 16, 0), ends_at: zone.local(2026, 10, 17, 0))
      end

      get admin_availability_path(business)

      expect(response.body).to include("No hay horarios libres esta semana.", "Ir al próximo: jue 22 oct")
    end

    it "explains when there is nothing to book" do
      in_business { service.deactivate! }

      get admin_availability_path(business)

      expect(response.body).to include("Todavía no hay nada para reservar.", admin_professionals_path(business))
    end
  end

  describe "as a professional" do
    let(:user) { member(:professional) }

    before { sign_in_as(user) }

    it "shows their own free times, without choosing a professional" do
      in_business { martin.update!(user: user) }
      works(martin, 4, "09:00", "10:00")
      works(sofia, 5, "15:00", "16:00")

      get admin_availability_path(business, professional_id: sofia.id)

      expect(response.body).to include("Tus horarios libres", "09:00")
      expect(response.body).not_to include("15:00", "Cualquiera")
    end

    it "explains when their profile can't be booked" do
      in_business { martin.update!(user: user) }

      get admin_availability_path(business)

      expect(response.body).to include("Tu perfil todavía no recibe turnos.")
    end

    it "explains when they have no profile" do
      get admin_availability_path(business)

      expect(response.body).to include("No tenés un perfil de profesional.")
    end
  end
end
