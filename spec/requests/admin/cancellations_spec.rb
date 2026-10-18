require "rails_helper"

RSpec.describe "Admin cancellations", type: :request do
  let(:business) { create(:business) }
  let(:manager) { create(:membership, :owner, business: business).user }
  let(:appointment) do
    with_business(business) do
      create(:appointment, starts_at: 2.days.from_now, customer: create(:customer, name: "Ana Pérez")).tap { |created| created.confirm!(by: manager) }
    end
  end

  before { sign_in_as(manager) }

  it "cancels a confirmed appointment with the reason" do
    get new_admin_appointment_cancellation_path(business, appointment)
    expect(response.body).to include("Cancelar turno", "Ana Pérez")

    post admin_appointment_cancellation_path(business, appointment), params: { cancellation: { note: "El profesional está enfermo" } }

    expect(response).to redirect_to(admin_appointment_url(business, appointment))
    expect(flash[:notice]).to eq("Cancelamos el turno de Ana Pérez.")
    with_business(business) do
      expect(appointment.reload).to be_cancelled
      expect(appointment.events.last.note).to eq("El profesional está enfermo")
    end
  end

  it "requires the reason" do
    post admin_appointment_cancellation_path(business, appointment), params: { cancellation: { note: "" } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Motivo no puede estar en blanco")
    with_business(business) { expect(appointment.reload).to be_confirmed }
  end

  it "is not possible once the appointment started" do
    travel_to(appointment.starts_at + 1.minute) do
      get new_admin_appointment_cancellation_path(business, appointment)
      expect(response).to redirect_to(admin_appointment_url(business, appointment))

      post admin_appointment_cancellation_path(business, appointment), params: { cancellation: { note: "Tarde" } }
      expect(flash[:alert]).to include("confirmado")
    end
    with_business(business) { expect(appointment.reload).to be_confirmed }
  end
end
