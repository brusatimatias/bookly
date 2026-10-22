require "rails_helper"

RSpec.describe "Appointment reschedules", type: :request do
  let(:business) do
    create(:business, name: "Barbería Centro", time_zone: "America/Argentina/Buenos_Aires", min_booking_notice_hours: 0,
                      booking_horizon_days: 30, cancellation_window_hours: 24, request_expiration_hours: 24, buffer_minutes: 0)
  end
  let(:zone) { Time.find_zone!(business.time_zone) }
  # A Wednesday morning.
  let(:now) { zone.local(2026, 10, 14, 8) }
  let(:service) { in_business { create(:service, name: "Corte de pelo", duration_minutes: 30, buffer_minutes: nil) } }
  let(:martin) { in_business { create(:professional, name: "Martín Gómez", services: [ service ]) } }
  let(:sofia) { in_business { create(:professional, name: "Sofía Torres", services: [ service ]) } }
  let(:customer) { in_business { create(:customer, name: "Ana Pérez") } }
  # Friday 16 at 15:00: the customer can change it until Thursday 15:00.
  let(:friday_three) { zone.local(2026, 10, 16, 15) }
  let(:appointment) { book(martin, friday_three, customer: customer, status: :confirmed) }
  let(:token) { in_business { appointment.generate_token_for(:management) } }

  around { |example| travel_to(now) { example.run } }
  before { use_business_host(business) }

  before do
    in_business do
      [ martin, sofia ].each { |professional| create(:working_hour, professional: professional, day_of_week: 5, start_time: "15:00", end_time: "17:00") }
    end
  end

  def in_business(&block)
    with_business(business, &block)
  end

  def book(professional, starts_at, status: :pending, **attributes)
    in_business { create(:appointment, service: service, professional: professional, starts_at: starts_at, status: status, **attributes) }
  end

  def reschedule_to(starts_at)
    post appointment_reschedule_path(token), params: { starts_at: starts_at.iso8601 }
  end

  it "is offered on a confirmed appointment's page" do
    get appointment_path(token)

    expect(response.body).to include("Podés cancelarlo o cambiar el horario hasta el jue 15 oct, 15:00.", "Cambiar horario",
                                     new_appointment_reschedule_path(token))
  end

  it "is not offered on a request" do
    in_business { appointment.update_columns(status: "pending", request_expires_at: now + 1.day) }

    get appointment_path(token)

    expect(response.body).not_to include(new_appointment_reschedule_path(token))
  end

  describe "choosing a time" do
    it "shows the week of the appointment with the professional's free times, except the current one" do
      book(martin, friday_three + 1.hour)

      get new_appointment_reschedule_path(token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Cambiar el horario", "Tu horario actual", "vie 16 oct, 15:00 – 15:30", "Corte de pelo · Martín Gómez",
                                       "lun 12 oct – dom 18 oct", ">15:30<", ">16:30<")
      expect(response.body).not_to include(">15:00<", ">16:00<")
      expect(response.body).to include('<meta name="robots" content="noindex, nofollow">')
    end

    it "shows anyone's free times when the customer asked for any professional" do
      in_business { appointment.update_column(:any_professional, true) }
      book(martin, friday_three + 1.hour)

      get new_appointment_reschedule_path(token)

      expect(response.body).to include(">16:00<")
      expect(response.body).not_to include("· Martín Gómez")
    end

    it "refreshes itself when an appointment changes" do
      get new_appointment_reschedule_path(token)

      expect(response.body).to include(%(signed-stream-name="#{signed_turbo_stream_name(Appointment.availability_stream(business))}"))
    end

    it "asks to confirm the chosen time, warning what it means" do
      get new_appointment_reschedule_path(token, starts_at: (friday_three + 1.hour).iso8601)

      expect(response.body).to include("Horario nuevo", "vie 16 oct, 16:00 – 16:30", "Tu horario actual se libera ahora", "Pedir el cambio")
      expect(response.body).not_to include("turbo-cable-stream-source")
    end

    it "goes back to the week for a time that isn't free" do
      book(sofia, friday_three + 1.hour)
      book(martin, friday_three + 1.hour)

      get new_appointment_reschedule_path(token, starts_at: (friday_three + 1.hour).iso8601)

      expect(response.body).to include("Ese horario ya no está disponible. Elegí otro.", "¿Cuándo te queda mejor?")
    end
  end

  describe "requesting the change" do
    it "moves the appointment back to pending at the new time" do
      reschedule_to(friday_three + 1.hour)

      expect(response).to redirect_to(appointment_path(token))
      expect(flash[:notice]).to eq("Listo, pedimos el cambio de horario. El negocio lo va a confirmar.")
      in_business { expect(appointment.reload).to have_attributes(status: "pending", starts_at: friday_three + 1.hour, professional: martin) }

      follow_redirect!
      expect(response.body).to include("Cambio de horario pedido", "Pediste pasar tu turno del vie 16 oct, 15:00 a este horario",
                                       "vie 16 oct, 16:00 – 16:30")
    end

    it "sends the customer back to the week when the time was taken meanwhile" do
      book(martin, friday_three + 1.hour)

      reschedule_to(friday_three + 1.hour)

      expect(response).to redirect_to(new_appointment_reschedule_path(token, week: "2026-10-16"))
      expect(flash[:alert]).to eq("Ese horario ya no está disponible. Elegí otro.")
      expect(in_business { appointment.reload }).to have_attributes(status: "confirmed", starts_at: friday_three)
    end

    it "explains when the customer has another appointment then" do
      book(sofia, friday_three + 1.hour, customer: customer)

      reschedule_to(friday_three + 1.hour)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Ya tenés otro turno que se superpone con este horario.")
      expect(in_business { appointment.reload }.starts_at).to eq(friday_three)
    end
  end

  it "is not possible once the window closed" do
    appointment
    travel_to(zone.local(2026, 10, 15, 15, 1))

    get new_appointment_reschedule_path(token)
    expect(response).to redirect_to(appointment_path(token))
    expect(flash[:alert]).to eq("Este turno ya no se puede cambiar desde acá.")

    reschedule_to(friday_three + 1.hour)
    expect(response).to redirect_to(appointment_path(token))
    expect(in_business { appointment.reload }.starts_at).to eq(friday_three)
  end

  it "is not possible for a request" do
    in_business { appointment.update_columns(status: "pending", request_expires_at: now + 1.day) }

    reschedule_to(friday_three + 1.hour)

    expect(flash[:alert]).to eq("Este turno ya no se puede cambiar desde acá.")
    expect(in_business { appointment.reload }.starts_at).to eq(friday_three)
  end

  it "doesn't find another business's appointment" do
    use_business_host(create(:business))
    post appointment_reschedule_path(token), params: { starts_at: (friday_three + 1.hour).iso8601 }

    expect(response).to have_http_status(:not_found)
  end

  it "is in the business's language" do
    business.update!(locale: "en")

    get new_appointment_reschedule_path(token)

    expect(response.body).to include('lang="en"', "Change the time", "When suits you best?")
  end
end
