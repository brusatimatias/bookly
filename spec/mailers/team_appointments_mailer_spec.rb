require "rails_helper"

RSpec.describe TeamAppointmentsMailer, type: :mailer do
  let(:business) do
    create(:business, name: "Barbería Centro", time_zone: "America/Argentina/Buenos_Aires", request_expiration_hours: 24,
                      contact_email: "hola@barberia.example")
  end
  let(:zone) { Time.find_zone!(business.time_zone) }
  let(:service) { in_business { create(:service, name: "Corte de pelo", duration_minutes: 30) } }
  let(:professional) do
    in_business do
      create(:professional, name: "Martín Gómez", services: [ service ])
        .tap { |created| create(:working_hour, professional: created, day_of_week: 5, start_time: "09:00", end_time: "18:00") }
    end
  end
  let(:appointment) do
    in_business do
      create(:appointment, service: service, professional: professional, starts_at: zone.local(2026, 10, 16, 15), customer_notes: "Pelo largo",
                           customer: create(:customer, name: "Ana Pérez", email: "ana@example.com", phone: "+54 11 5555-0101"))
    end
  end
  let(:recipient) { create(:membership, :owner, business: business, user: create(:user, name: "Lucía", email_address: "lucia@example.com")).user }

  # A Wednesday morning.
  around { |example| travel_to(zone.local(2026, 10, 14, 8)) { example.run } }

  def in_business(&block)
    with_business(business, &block)
  end

  def mailer(event = nil)
    described_class.with(business: business, appointment_id: appointment.id, event_id: event&.id, recipient: recipient)
  end

  def last_event
    in_business { appointment.events.reload.last }
  end

  def text(mail)
    mail.text_part.body.to_s
  end

  describe "#new_request" do
    it "tells the member about the request, the customer and the deadline, with a link to the panel" do
      mail = mailer.new_request

      expect(mail.to).to eq([ "lucia@example.com" ])
      expect(mail.reply_to).to eq([ "ana@example.com" ])
      expect(mail.subject).to eq("Nuevo pedido de turno: Ana Pérez, vie 16 oct, 15:00")
      expect(text(mail)).to include("Hola, Lucía:", "Ana Pérez pidió un turno. Hay tiempo hasta el jue 15 oct, 08:00",
                                    "Corte de pelo", "Martín Gómez", "Cliente: Ana Pérez (ana@example.com · +54 11 5555-0101)",
                                    "Comentarios: Pelo largo", "/barberia-centro/admin/appointments/#{appointment.id}",
                                    "Si respondés este email, le escribís a Ana Pérez.")
    end
  end

  describe "#customer_rescheduled" do
    it "gives the old and new time and the deadline" do
      in_business do
        appointment.confirm!(by: recipient)
        appointment.reschedule!(zone.local(2026, 10, 16, 17))
      end

      mail = mailer(last_event).customer_rescheduled

      expect(mail.subject).to eq("Ana Pérez pidió cambiar el horario de su turno")
      expect(text(mail)).to include("Ana Pérez pidió pasar su turno del vie 16 oct, 15:00 al vie 16 oct, 17:00.",
                                    "hay tiempo hasta el jue 15 oct, 08:00 para confirmar o rechazar el nuevo")
    end
  end

  describe "#customer_cancelled" do
    it "gives the customer's reason for a cancellation" do
      in_business do
        appointment.confirm!(by: recipient)
        appointment.cancel!(by: :customer, reason: "Me surgió algo")
      end

      mail = mailer(last_event).customer_cancelled

      expect(mail.subject).to eq("Ana Pérez canceló su turno del vie 16 oct, 15:00")
      expect(text(mail)).to include("Motivo del cliente:\nMe surgió algo")
    end

    it "says when a request was withdrawn" do
      in_business { appointment.cancel!(by: :customer) }

      mail = mailer(last_event).customer_cancelled

      expect(mail.subject).to eq("Ana Pérez retiró su pedido de turno del vie 16 oct, 15:00")
      expect(text(mail)).not_to include("Motivo del cliente")
    end
  end

  it "is written in the business's language" do
    business.update!(locale: "en")

    expect(mailer.new_request.subject).to eq("New appointment request: Ana Pérez, Fri, Oct 16, 3:00 PM")
  end
end
