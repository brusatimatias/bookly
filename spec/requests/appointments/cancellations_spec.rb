require "rails_helper"

RSpec.describe "Appointment cancellations", type: :request do
  let(:business) { create(:business, name: "Barbería Centro", time_zone: "America/Argentina/Buenos_Aires", cancellation_window_hours: 24) }
  let(:zone) { Time.find_zone!(business.time_zone) }
  # A Wednesday morning.
  let(:now) { zone.local(2026, 10, 14, 8) }
  let(:service) { in_business { create(:service, name: "Corte de pelo", duration_minutes: 30) } }
  let(:professional) { in_business { create(:professional, name: "Martín Gómez", services: [ service ]) } }
  # Friday 16 at 15:00: the customer can cancel until Thursday 15:00.
  let(:appointment) { in_business { create(:appointment, service: service, professional: professional, starts_at: zone.local(2026, 10, 16, 15)) } }
  let(:token) { in_business { appointment.generate_token_for(:management) } }

  around { |example| travel_to(now) { example.run } }
  before { use_business_host(business) }

  def in_business(&block)
    with_business(business, &block)
  end

  def confirm
    in_business { appointment.confirm!(by: create(:user)) }
  end

  def cancel(note: "")
    post appointment_cancellation_path(token), params: { cancellation: { note: note } }
  end

  it "asks to confirm withdrawing a request" do
    get new_appointment_cancellation_path(token)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Retirar el pedido", "Corte de pelo", "vie 16 oct, 15:00 – 15:30", "Motivo (opcional)")
    expect(response.body).to include('<meta name="robots" content="noindex, nofollow">')
  end

  it "withdraws a request, with an optional reason" do
    cancel(note: "Me surgió algo")

    expect(response).to redirect_to(appointment_path(token))
    expect(flash[:notice]).to eq("Listo, cancelamos tu turno.")
    in_business do
      expect(appointment.reload).to be_cancelled
      expect(appointment.events.last).to have_attributes(actor_kind: "customer", note: "Me surgió algo")
    end
  end

  it "cancels a confirmed appointment without a reason" do
    confirm

    get new_appointment_cancellation_path(token)
    expect(response.body).to include("Cancelar el turno")

    cancel

    expect(in_business { appointment.reload }).to be_cancelled
  end

  it "shows the errors, keeping what was typed" do
    cancel(note: "a" * 501)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("es demasiado largo", "a" * 501)
    expect(in_business { appointment.reload }).to be_pending
  end

  it "is not possible once the window closed" do
    confirm
    travel_to(zone.local(2026, 10, 15, 15, 1))

    get new_appointment_cancellation_path(token)
    expect(response).to redirect_to(appointment_path(token))
    expect(flash[:alert]).to eq("Este turno ya no se puede cambiar desde acá.")

    cancel
    expect(response).to redirect_to(appointment_path(token))
    expect(in_business { appointment.reload }).to be_confirmed
  end

  it "is not possible once the business answered" do
    in_business { appointment.reject!(by: create(:user), reason: "Cerrado") }

    cancel

    expect(flash[:alert]).to eq("Este turno ya no se puede cambiar desde acá.")
    expect(in_business { appointment.reload }).to be_rejected
  end

  it "limits the changes from one address" do
    10.times { cancel(note: "a" * 501) }

    cancel

    expect(flash[:alert]).to eq("Hiciste demasiados cambios seguidos. Probá de nuevo en unos minutos.")
    expect(in_business { appointment.reload }).to be_pending
  end

  it "doesn't find a tampered token or another business's appointment" do
    post appointment_cancellation_path("#{token}x")
    expect(response).to have_http_status(:not_found)

    use_business_host(create(:business))
    post appointment_cancellation_path(token)
    expect(response).to have_http_status(:not_found)
    expect(in_business { appointment.reload }).to be_pending
  end

  it "is in the business's language" do
    business.update!(locale: "en")

    get new_appointment_cancellation_path(token)

    expect(response.body).to include('lang="en"', "Withdraw the request", "Reason (optional)")
  end
end
