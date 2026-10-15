require "rails_helper"

RSpec.describe "Admin rejections", type: :request do
  let(:business) { create(:business) }
  let(:own_membership) { create(:membership, business: business) }
  let(:appointment) do
    with_business(business) do
      service = create(:service)
      create(:appointment, service: service, professional: create(:professional, user: own_membership.user, services: [ service ]),
                           customer: create(:customer, name: "Ana Pérez"))
    end
  end

  before { sign_in_as(own_membership.user) }

  it "asks for the reason" do
    get new_admin_appointment_rejection_path(business, appointment)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Rechazar pedido", "Ana Pérez", "Motivo", "El cliente lo va a ver")
  end

  it "rejects the request with the reason" do
    post admin_appointment_rejection_path(business, appointment), params: { rejection: { note: "Cerramos ese día" } }

    expect(response).to redirect_to(admin_requests_url(business))
    expect(flash[:notice]).to eq("Rechazamos el pedido de Ana Pérez.")
    with_business(business) do
      expect(appointment.reload).to be_rejected
      expect(appointment.events.last).to have_attributes(note: "Cerramos ese día", actor_user: own_membership.user)
    end
  end

  it "requires the reason" do
    post admin_appointment_rejection_path(business, appointment), params: { rejection: { note: "  " } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Motivo no puede estar en blanco")
    with_business(business) { expect(appointment.reload).to be_pending }
  end

  it "doesn't apply to answered requests" do
    with_business(business) { appointment.confirm!(by: own_membership.user) }

    get new_admin_appointment_rejection_path(business, appointment)

    expect(response).to redirect_to(admin_appointment_url(business, appointment))
    expect(flash[:alert]).to include("confirmado")
  end

  it "responds not found for another professional's request" do
    sign_in_as(create(:membership, business: business).user)

    post admin_appointment_rejection_path(business, appointment), params: { rejection: { note: "No" } }

    expect(response).to have_http_status(:not_found)
  end
end
