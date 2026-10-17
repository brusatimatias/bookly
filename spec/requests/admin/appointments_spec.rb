require "rails_helper"

RSpec.describe "Admin appointments", type: :request do
  let(:business) { create(:business, request_expiration_hours: 24) }
  let(:service) { in_business { create(:service, name: "Corte", price_cents: 12_000_00) } }
  let(:own_membership) { create(:membership, business: business) }
  let(:own_profile) { in_business { create(:professional, name: "Martín", user: own_membership.user, services: [ service ]) } }
  let(:customer) { in_business { create(:customer, name: "Ana Pérez", email: "ana@example.com", phone: "+54 11 5555-0101") } }
  let(:appointment) do
    in_business { create(:appointment, service: service, professional: own_profile, customer: customer, starts_at: 2.days.from_now, customer_notes: "Corto atrás") }
  end
  let(:manager) { create(:membership, :admin, business: business).user }

  def in_business(&block)
    with_business(business, &block)
  end

  describe "the appointment page" do
    it "shows the details, the customer's contact, the history and the actions" do
      sign_in_as(manager)
      in_business { appointment.events.create!(to_status: "pending", actor_kind: :customer) }

      get admin_appointment_path(business, appointment)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ana Pérez", "ana@example.com", "tel:+541155550101", "Corte", "$ 12.000", "Martín", "Corto atrás")
      expect(response.body).to include("Pedido enviado", "Confirmar", "Rechazar", "Reasignar")
    end

    it "shows the reasons and reassignments in the history" do
      sofia = in_business { create(:professional, name: "Sofía", services: [ service ]) }
      in_business do
        appointment.events.create!(from_status: "pending", to_status: "pending", actor_kind: :user, actor_user: manager,
                                   metadata: { from_professional_id: sofia.id, to_professional_id: own_profile.id })
        appointment.events.create!(from_status: "pending", to_status: "rejected", actor_kind: :user, actor_user: manager, note: "Cerramos ese día")
      end
      sign_in_as(manager)

      get admin_appointment_path(business, appointment)

      expect(response.body).to include("Reasignado de Sofía a Martín", "Cerramos ese día", manager.name)
    end

    it "shows a customer's change of time, in the details and the history" do
      zone = Time.find_zone!(business.time_zone)
      in_business do
        appointment.update!(starts_at: zone.local(2026, 10, 20, 10))
        create(:appointment_event, :reschedule, appointment: appointment, from: zone.local(2026, 10, 19, 12))
      end
      sign_in_as(manager)

      get admin_appointment_path(business, appointment)

      expect(response.body).to include("Cambio de horario · antes lun 19 oct, 12:00", "Horario cambiado del lun 19 oct, 12:00 al mar 20 oct, 10:00",
                                       "Cliente")
    end

    it "shows the customer's cancellation with their reason" do
      in_business { appointment.cancel!(by: :customer, reason: "Me surgió algo") }
      sign_in_as(manager)

      get admin_appointment_path(business, appointment)

      expect(response.body).to include("Cancelado", "Cliente", "Me surgió algo")
    end

    it "lets professionals see their own appointments, without reassigning" do
      sign_in_as(own_membership.user)

      get admin_appointment_path(business, appointment)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Confirmar")
      expect(response.body).not_to include("Reasignar")
    end

    it "responds not found for another professional's appointment or another business's" do
      sign_in_as(create(:membership, business: business).user)
      get admin_appointment_path(business, appointment)
      expect(response).to have_http_status(:not_found)

      sign_in_as(create(:membership, :owner, business: create(:business)).user)
      get admin_appointment_path(business, appointment)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "confirming" do
    it "confirms the request and goes back" do
      sign_in_as(own_membership.user)

      patch confirm_admin_appointment_path(business, appointment), headers: { "HTTP_REFERER" => admin_requests_url(business) }

      expect(response).to redirect_to(admin_requests_url(business))
      expect(flash[:notice]).to eq("Confirmamos el turno de Ana Pérez.")
      in_business { expect(appointment.reload).to be_confirmed }
      in_business { expect(appointment.events.last.actor_user).to eq(own_membership.user) }
    end

    it "explains when it was already answered" do
      in_business { appointment.reject!(by: manager, reason: "Cerrado") }
      sign_in_as(own_membership.user)

      patch confirm_admin_appointment_path(business, appointment)

      expect(response).to redirect_to(admin_appointment_url(business, appointment))
      expect(flash[:alert]).to eq("No se pudo hacer el cambio: el turno está rechazado.")
    end

    it "expires a request whose deadline passed" do
      sign_in_as(manager)
      appointment

      travel_to(25.hours.from_now) { patch confirm_admin_appointment_path(business, appointment) }

      expect(flash[:alert]).to eq("No se pudo hacer el cambio: el turno está vencido.")
      in_business { expect(appointment.reload).to be_expired }
    end

    it "can't touch another professional's appointment" do
      sign_in_as(create(:membership, business: business).user)

      patch confirm_admin_appointment_path(business, appointment)

      expect(response).to have_http_status(:not_found)
      in_business { expect(appointment.reload).to be_pending }
    end
  end

  describe "attendance" do
    before { in_business { appointment.confirm!(by: manager) } }

    it "marks attended or no show once the appointment started" do
      sign_in_as(own_membership.user)

      travel_to(appointment.starts_at + 10.minutes) do
        get admin_appointment_path(business, appointment)
        expect(response.body).to include("Atendido", "Ausente")

        patch attended_admin_appointment_path(business, appointment)
      end

      expect(response).to redirect_to(admin_appointment_url(business, appointment))
      in_business { expect(appointment.reload).to be_attended }
    end

    it "marks no show" do
      sign_in_as(manager)

      travel_to(appointment.starts_at + 10.minutes) { patch no_show_admin_appointment_path(business, appointment) }

      in_business { expect(appointment.reload).to be_no_show }
    end

    it "is refused before the start" do
      sign_in_as(manager)

      patch attended_admin_appointment_path(business, appointment)

      expect(flash[:alert]).to eq("No se pudo hacer el cambio: el turno está confirmado.")
      in_business { expect(appointment.reload).to be_confirmed }
    end
  end
end
