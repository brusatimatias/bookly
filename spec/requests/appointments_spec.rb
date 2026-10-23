require "rails_helper"

RSpec.describe "Appointments", type: :request do
  let(:business) do
    create(:business, name: "Barbería Centro", time_zone: "America/Argentina/Buenos_Aires", request_expiration_hours: 24,
                      contact_phone: "+54 11 5555-0101")
  end
  let(:zone) { Time.find_zone!(business.time_zone) }
  # A Wednesday morning.
  let(:now) { zone.local(2026, 10, 14, 8) }
  let(:service) { in_business { create(:service, name: "Corte de pelo", duration_minutes: 30, price_cents: 12_000_00) } }
  let(:professional) { in_business { create(:professional, name: "Martín Gómez", services: [ service ]) } }
  let(:customer) { in_business { create(:customer, name: "Ana Pérez") } }
  let(:appointment) do
    in_business do
      create(:appointment, service: service, professional: professional, customer: customer, starts_at: zone.local(2026, 10, 16, 15),
                           customer_notes: "Pelo largo")
    end
  end
  let(:token) { in_business { appointment.generate_token_for(:management) } }

  around { |example| travel_to(now) { example.run } }
  before { use_business_host(business) }

  def in_business(&block)
    with_business(business, &block)
  end

  it "shows a pending request with its details and the business's contact" do
    get appointment_path(token)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Pedido enviado", "Pendiente", "Gracias, Ana Pérez", "tiene hasta el jue 15 oct, 08:00 para confirmarlo")
    expect(response.body).to include("vie 16 oct, 15:00 – 15:30", "Hora de Buenos Aires", "Corte de pelo", "$ 12.000", "Martín Gómez",
                                     "Pelo largo", "+54 11 5555-0101", "Guardá este link")
    expect(response.body).to include('<meta name="robots" content="noindex, nofollow">')
    expect(response.body).not_to include("Asignado entre los profesionales disponibles.")
  end

  it "says when the professional was assigned" do
    in_business { appointment.update!(any_professional: true) }

    get appointment_path(token)

    expect(response.body).to include("Asignado entre los profesionales disponibles.")
  end

  it "explains other statuses" do
    in_business { appointment.update!(status: :confirmed) }

    get appointment_path(token)

    expect(response.body).to include("Turno confirmado", "Confirmado", "Te esperamos en Barbería Centro.")
  end

  it "shows the business's reason for a rejection or cancellation" do
    in_business { appointment.reject!(by: create(:user), reason: "Ese día cerramos por inventario.") }

    get appointment_path(token)

    expect(response.body).to include("Pedido rechazado", "Motivo de Barbería Centro", "Ese día cerramos por inventario.")
  end

  it "has no reason box for other statuses" do
    in_business { appointment.confirm!(by: create(:user)) }

    get appointment_path(token)

    expect(response.body).not_to include("Motivo de")
  end

  it "says when the business reassigned the appointment" do
    in_business do
      other = create(:professional, name: "Sofía Torres", services: [ service ])
      create(:working_hour, professional: other, day_of_week: 5, start_time: "14:00", end_time: "18:00")
      appointment.update!(any_professional: true)
      appointment.reassign!(other, by: create(:user))
    end

    get appointment_path(token)

    expect(response.body).to include("Sofía Torres", "Barbería Centro reasignó tu turno a este profesional.")
    expect(response.body).not_to include("Asignado entre los profesionales disponibles.")
  end

  describe "what the customer can do" do
    it "offers withdrawing a request" do
      get appointment_path(token)

      expect(response.body).to include("Podés retirar el pedido.", new_appointment_cancellation_path(token))
    end

    it "offers cancelling a confirmed appointment until the window closes" do
      in_business { appointment.confirm!(by: create(:user)) }

      get appointment_path(token)

      expect(response.body).to include("Podés cancelarlo o cambiar el horario hasta el jue 15 oct, 15:00.", "Cancelar turno")
    end

    it "sends the customer to the business once the window closed" do
      in_business { appointment.confirm!(by: create(:user)) }
      travel_to(zone.local(2026, 10, 15, 15, 1))

      get appointment_path(token)

      expect(response.body).to include("Faltan menos de 24 h para el turno: para cancelarlo o cambiarlo, contactá a Barbería Centro.")
      expect(response.body).not_to include(new_appointment_cancellation_path(token))
    end

    it "offers nothing once the appointment is over" do
      in_business { appointment.reject!(by: create(:user), reason: "No") }

      get appointment_path(token)

      expect(response.body).not_to include(new_appointment_cancellation_path(token), "Faltan menos de")
    end
  end

  it "says when the customer cancelled it, without showing their reason as the business's" do
    in_business { appointment.cancel!(by: :customer, reason: "Me surgió algo") }

    get appointment_path(token)

    expect(response.body).to include("Turno cancelado", "Lo cancelaste y el horario se liberó.")
    expect(response.body).not_to include("Motivo de", "Me surgió algo")
  end

  describe "adding it to a calendar" do
    it "offers the .ics for a confirmed appointment" do
      in_business { appointment.confirm!(by: create(:user)) }

      get appointment_path(token)
      expect(response.body).to include("Agregar al calendario", appointment_path(token, format: :ics))

      get appointment_path(token, format: :ics)
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/calendar")
      expect(response.headers["Content-Disposition"]).to include('filename="turno.ics"')
      # Long lines are folded: unfold them first.
      expect(response.body.gsub("\r\n ", "")).to include("METHOD:PUBLISH", "DTSTART:20261016T180000Z", "http://#{business_host(business)}/appointments/#{token}")
    end

    it "has no .ics for other statuses" do
      get appointment_path(token)
      expect(response.body).not_to include("Agregar al calendario")

      get appointment_path(token, format: :ics)
      expect(response).to have_http_status(:not_found)
    end
  end

  it "keeps the price the appointment was booked with" do
    token
    in_business { service.update!(price_cents: 20_000_00) }

    get appointment_path(token)

    expect(response.body).to include("$ 12.000")
  end

  it "is in the business's language" do
    business.update!(locale: "en")

    get appointment_path(token)

    expect(response.body).to include('lang="en"', "Request sent", "Fri, Oct 16, 3:00 PM – 3:30 PM")
  end

  it "doesn't find a tampered token" do
    get appointment_path("#{token}x")

    expect(response).to have_http_status(:not_found)
  end

  it "doesn't find an appointment through another business" do
    use_business_host(create(:business))
    get appointment_path(token)

    expect(response).to have_http_status(:not_found)
  end

  it "shows a suspended business as unavailable" do
    token
    business.suspend!

    get appointment_path(token)

    expect(response).to have_http_status(:service_unavailable)
    expect(response.body).not_to include("Ana Pérez")
  end
end
