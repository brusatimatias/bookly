require "rails_helper"

RSpec.describe "Bookings", type: :request do
  let(:business) do
    create(:business, time_zone: "America/Argentina/Buenos_Aires", min_booking_notice_hours: 0, booking_horizon_days: 30)
  end
  let(:zone) { Time.find_zone!(business.time_zone) }
  # A Wednesday morning.
  let(:now) { zone.local(2026, 10, 14, 8) }
  let(:haircut) { in_business { create(:service, name: "Corte de pelo", duration_minutes: 30, price_cents: 12_000_00) } }
  let(:beard) { in_business { create(:service, name: "Arreglo de barba", duration_minutes: 20) } }
  let(:martin) { in_business { create(:professional, name: "Martín Gómez", services: [ haircut, beard ]) } }
  let(:sofia) { in_business { create(:professional, name: "Sofía Torres", services: [ haircut ]) } }
  # Thursday 15 at 09:00.
  let(:thursday_nine) { zone.local(2026, 10, 15, 9) }

  around { |example| travel_to(now) { example.run } }

  before do
    works(martin, 4, "09:00", "10:00")
    works(sofia, 5, "15:00", "16:00")
  end

  def in_business(&block)
    with_business(business, &block)
  end

  def works(professional, day_of_week, start_time, end_time)
    in_business { create(:working_hour, professional: professional, day_of_week: day_of_week, start_time: start_time, end_time: end_time) }
  end

  it "is offered from the public page, for the business and for each service and professional" do
    get business_path(business)

    expect(response.body).to include(new_booking_path(business), new_booking_path(business, service_id: haircut.id),
                                     new_booking_path(business, professional_id: martin.id))
  end

  describe "choosing a service" do
    it "lists the bookable services" do
      in_business { create(:service, name: "Coloración") }

      get new_booking_path(business)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Pedí tu turno", "Corte de pelo", "Arreglo de barba")
      expect(response.body).not_to include("Coloración")
    end

    it "lists only the professional's services when starting from them" do
      get new_booking_path(business, professional_id: sofia.id)

      expect(response.body).to include("¿Qué servicio querés con Sofía Torres?", "Corte de pelo")
      expect(response.body).not_to include("Arreglo de barba")
      expect(response.body).to include(CGI.escapeHTML(new_booking_path(business, service_id: haircut.id, professional_id: sofia.id)))
    end

    it "ignores services that can't be booked" do
      inactive = in_business { create(:service, name: "Viejo", active: false, professionals: [ martin ]) }

      get new_booking_path(business, service_id: inactive.id)

      expect(response.body).to include("¿Qué servicio querés?")
    end

    it "ignores services of another business" do
      foreign = with_business(create(:business)) { create(:service) }

      get new_booking_path(business, service_id: foreign.id)

      expect(response.body).to include("¿Qué servicio querés?")
    end

    it "explains when there is nothing to book" do
      get new_booking_path(create(:business))

      expect(response.body).to include("No hay servicios para reservar.")
    end
  end

  describe "choosing a professional" do
    it "offers any professional and each one offering the service" do
      get new_booking_path(business, service_id: haircut.id)

      expect(response.body).to include("¿Con quién?", "Cualquier profesional", "Martín Gómez", "Sofía Torres")
      expect(response.body).to include(CGI.escapeHTML(new_booking_path(business, service_id: haircut.id, professional_id: "any")))
    end

    it "skips the step when a single professional offers the service" do
      get new_booking_path(business, service_id: beard.id)

      expect(response.body).to include("¿Cuándo?", "Martín Gómez")
      expect(response.body).not_to include("¿Con quién?")
    end

    it "asks again for a professional who doesn't offer the service" do
      get new_booking_path(business, service_id: beard.id, professional_id: sofia.id)

      expect(response.body).to include("¿Cuándo?", "Martín Gómez")

      get new_booking_path(business, service_id: haircut.id, professional_id: in_business { create(:professional, name: "Otro").id })

      expect(response.body).to include("¿Con quién?")
    end
  end

  describe "choosing a time" do
    it "shows the week's free times of any professional, without saying who" do
      get new_booking_path(business, service_id: haircut.id, professional_id: "any")

      expect(response.body).to include("¿Cuándo?", "lun 12 oct – dom 18 oct", "09:00", "15:30", "Ya pasó")
      expect(response.body).not_to include('title="Martín Gómez"')
      expect(response.body).to include(CGI.escapeHTML(new_booking_path(business, service_id: haircut.id, professional_id: "any",
                                                                         starts_at: thursday_nine.iso8601)))
    end

    it "shows only the chosen professional's free times" do
      get new_booking_path(business, service_id: haircut.id, professional_id: sofia.id)

      expect(response.body).to include("Sofía Torres", "15:00")
      expect(response.body).not_to include(">09:00<")
    end

    it "moves between weeks within the booking window" do
      get new_booking_path(business, service_id: haircut.id, professional_id: "any", week: "2026-10-21")

      expect(response.body).to include("lun 19 oct – dom 25 oct")
    end
  end

  describe "with a time chosen" do
    it "goes on to the details, summarizing the choices" do
      get new_booking_path(business, service_id: haircut.id, professional_id: "any", starts_at: thursday_nine.iso8601)

      expect(response.body).to include("Tus datos", "Corte de pelo", "$ 12.000", "Cualquier profesional", "jue 15 oct, 09:00 – 09:30")
      expect(response.body).not_to include("¿Cuándo?")
    end

    it "goes back to the week when the time is no longer free" do
      in_business { create(:appointment, service: haircut, professional: martin, starts_at: thursday_nine) }

      get new_booking_path(business, service_id: haircut.id, professional_id: martin.id, starts_at: thursday_nine.iso8601)

      expect(response.body).to include("Ese horario ya no está disponible. Elegí otro.", "¿Cuándo?", "lun 12 oct – dom 18 oct")
    end

    it "goes back to the week for a time that isn't a slot" do
      get new_booking_path(business, service_id: haircut.id, professional_id: "any", starts_at: (thursday_nine + 5.minutes).iso8601)

      expect(response.body).to include("Ese horario ya no está disponible. Elegí otro.", "¿Cuándo?")
    end

    it "ignores a malformed time" do
      get new_booking_path(business, service_id: haircut.id, professional_id: "any", starts_at: "tomorrow")

      expect(response.body).to include("¿Cuándo?")
      expect(response.body).not_to include("ya no está disponible")
    end
  end

  describe "sending the request" do
    let(:details) { { name: "Ana Pérez", email: "ana@example.com", phone: "", customer_notes: "" } }

    def send_request(professional_id: "any", starts_at: thursday_nine, **attributes)
      post bookings_path(business), params: { service_id: haircut.id, professional_id: professional_id, starts_at: starts_at.iso8601,
                                              appointment_request: details.merge(attributes) }
    end

    it "shows the form with the time chosen" do
      get new_booking_path(business, service_id: haircut.id, professional_id: "any", starts_at: thursday_nine.iso8601)

      expect(response.body).to include("Tus datos", "Pedir turno", "el negocio tiene hasta 24 h para confirmarlo")
    end

    it "creates a pending appointment for the customer" do
      expect { send_request }.to change { in_business { Appointment.count } }.by(1)

      in_business do
        expect(Appointment.last).to have_attributes(status: "pending", starts_at: thursday_nine, professional: martin, any_professional: true)
        expect(Appointment.last.customer.email).to eq("ana@example.com")
      end
      expect(response).to redirect_to(business_path(business))
      expect(flash[:notice]).to eq("¡Listo! Enviamos tu pedido. El negocio lo va a confirmar.")
    end

    it "shows the errors, keeping what was typed" do
      expect { send_request(name: "", email: "nope", customer_notes: "Pelo largo") }.not_to change { in_business { Appointment.count } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Nombre no puede estar en blanco", "Pelo largo", "nope", "jue 15 oct, 09:00 – 09:30")
    end

    it "sends the customer back to the week when the time was taken meanwhile" do
      in_business { create(:appointment, service: haircut, professional: martin, starts_at: thursday_nine) }

      expect { send_request(professional_id: martin.id) }.not_to change { in_business { Appointment.count } }

      expect(response).to redirect_to(new_booking_path(business, service_id: haircut.id, professional_id: martin.id,
                                                       starts_at: thursday_nine.iso8601))
      follow_redirect!
      expect(response.body).to include("Ese horario ya no está disponible. Elegí otro.", "¿Cuándo?")
    end

    it "explains when the customer already has an appointment then" do
      friday_three = zone.local(2026, 10, 16, 15)
      works(martin, 5, "15:00", "16:00")
      customer = in_business { create(:customer, email: "ana@example.com") }
      in_business { create(:appointment, service: haircut, professional: martin, customer: customer, starts_at: friday_three) }

      expect { send_request(professional_id: sofia.id, starts_at: friday_three) }.not_to change { in_business { Appointment.count } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Ya tenés un turno que se superpone con este horario.")
    end

    it "limits the requests from one address" do
      10.times { |index| send_request(email: "nope", name: "Intento #{index}") }
      expect(response).to have_http_status(:unprocessable_entity)

      send_request

      expect(response).to redirect_to(new_booking_path(business, service_id: haircut.id, professional_id: "any", starts_at: thursday_nine.iso8601))
      expect(flash[:alert]).to eq("Hiciste demasiados pedidos seguidos. Probá de nuevo en unos minutos.")
      expect(in_business { Appointment.count }).to eq(0)
    end

    it "ignores the parameters of another business" do
      foreign = with_business(create(:business)) { create(:service) }

      post bookings_path(business), params: { service_id: foreign.id, professional_id: "any", starts_at: thursday_nine.iso8601,
                                              appointment_request: details }

      expect(response).to redirect_to(new_booking_path(business, starts_at: thursday_nine.iso8601))
    end
  end

  it "is in the business's language" do
    business.update!(locale: "en")

    get new_booking_path(business, service_id: haircut.id)

    expect(response.body).to include('lang="en"', "Book your appointment", "Any professional")
  end

  it "shows a suspended business as unavailable" do
    business.suspend!

    get new_booking_path(business)

    expect(response).to have_http_status(:service_unavailable)
  end
end
