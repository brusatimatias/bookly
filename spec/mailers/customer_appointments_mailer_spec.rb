require "rails_helper"

RSpec.describe CustomerAppointmentsMailer, type: :mailer do
  let(:business) do
    create(:business, name: "Barbería Centro", time_zone: "America/Argentina/Buenos_Aires", request_expiration_hours: 24,
                      cancellation_window_hours: 24, contact_email: "hola@barberia.example", address: "Av. Corrientes 1234")
  end
  let(:zone) { Time.find_zone!(business.time_zone) }
  let(:service) { in_business { create(:service, name: "Corte de pelo", duration_minutes: 30, price_cents: 12_000_00) } }
  let(:appointment) do
    in_business do
      create(:appointment, service: service, professional: create(:professional, name: "Martín Gómez", services: [ service ]),
                           customer: create(:customer, name: "Ana Pérez", email: "ana@example.com"), starts_at: zone.local(2026, 10, 16, 15))
    end
  end
  let(:member) { create(:membership, business: business).user }

  # A Wednesday morning.
  around { |example| travel_to(zone.local(2026, 10, 14, 8)) { example.run } }

  def in_business(&block)
    with_business(business, &block)
  end

  def mailer(event = nil)
    described_class.with(business: business, appointment_id: appointment.id, event_id: event&.id)
  end

  def last_event
    in_business { appointment.events.reload.last }
  end

  def text(mail)
    mail.text_part.body.to_s
  end

  # The .ics attached to the email, if any.
  def calendar(mail)
    mail.attachments.find { |attachment| attachment.mime_type == "text/calendar" }&.decoded
  end

  def link_token(mail)
    text(mail)[%r{http://barberia-centro\.example\.com/appointments/(\S+)}, 1]
  end

  describe "#requested" do
    it "tells the customer the business has to confirm, with the details and their link" do
      mail = mailer.requested

      expect(mail.to).to eq([ "ana@example.com" ])
      expect(mail.subject).to eq("Recibimos tu pedido de turno en Barbería Centro")
      expect(text(mail)).to include("Hola, Ana Pérez:", "Barbería Centro tiene hasta el jue 15 oct, 08:00 para confirmarlo",
                                    "vie 16 oct, 15:00 – 15:30 (Hora de Buenos Aires)", "Corte de pelo (30 min · $ 12.000)",
                                    "Martín Gómez", "Av. Corrientes 1234", "Ver mi turno", "podés ver el estado del pedido o retirarlo")
      expect(mail.html_part.body.to_s).to include("Ver mi turno", MailerHelper::BRAND_COLOR)
      expect(in_business { Appointment.find_by_token_for(:management, link_token(mail)) }).to eq(appointment)
    end
  end

  describe "#confirmed" do
    it "says it's confirmed and until when the customer can change it" do
      in_business { appointment.confirm!(by: member) }

      mail = mailer(last_event).confirmed

      expect(mail.subject).to eq("Tu turno en Barbería Centro está confirmado")
      expect(text(mail)).to include("Barbería Centro confirmó tu turno.", "desde el link hasta el jue 15 oct, 15:00.")
      expect(mail.attachments.map(&:filename)).to eq([ "turno.ics" ])
      expect(calendar(mail)).to include("METHOD:PUBLISH", "DTSTART:20261016T180000Z", "SUMMARY:Corte de pelo – Barbería Centro")
    end

    it "sends the customer to the business once the window closed" do
      in_business { appointment.confirm!(by: member) }
      travel_to(zone.local(2026, 10, 15, 16))

      expect(text(mailer(last_event).confirmed)).to include("Para cancelarlo o cambiarlo, contactá a Barbería Centro.")
    end
  end

  describe "#rejected" do
    it "gives the business's reason and offers booking again" do
      in_business { appointment.reject!(by: member, reason: "Ese día cerramos por inventario.") }

      mail = mailer(last_event).rejected

      expect(mail.subject).to eq("Barbería Centro no pudo confirmar tu pedido de turno")
      expect(text(mail)).to include("Motivo de Barbería Centro:\nEse día cerramos por inventario.", "Pedir otro turno")
      expect(text(mail)).to include("http://barberia-centro.example.com/book?service_id=#{service.id}")
    end
  end

  describe "#cancelled" do
    it "gives the business's reason when it cancelled" do
      in_business do
        appointment.confirm!(by: member)
        appointment.cancel!(by: member, reason: "El profesional está enfermo.")
      end

      mail = mailer(last_event).cancelled

      expect(mail.subject).to eq("Barbería Centro canceló tu turno")
      expect(text(mail)).to include("Motivo de Barbería Centro:\nEl profesional está enfermo.")
      expect(calendar(mail)).to include("METHOD:CANCEL")
    end

    it "is a receipt when the customer cancelled, without their reason" do
      in_business do
        appointment.confirm!(by: member)
        appointment.cancel!(by: :customer, reason: "Me surgió algo")
      end

      mail = mailer(last_event).cancelled

      expect(mail.subject).to eq("Cancelaste tu turno en Barbería Centro")
      expect(text(mail)).to include("Tu turno quedó cancelado y el horario se liberó.")
      expect(text(mail)).not_to include("Motivo de", "Me surgió algo")
    end

    it "is a receipt for a withdrawn request" do
      in_business { appointment.cancel!(by: :customer) }

      mail = mailer(last_event).cancelled

      expect(mail.subject).to eq("Retiraste tu pedido de turno en Barbería Centro")
      expect(text(mail)).to include("Tu pedido quedó retirado")
      expect(calendar(mail)).to be_nil
    end
  end

  describe "#expired" do
    it "says the business didn't answer and offers booking again" do
      appointment
      travel_to(zone.local(2026, 10, 15, 9))
      in_business { appointment.expire! }

      mail = mailer(last_event).expired

      expect(mail.subject).to eq("Tu pedido de turno en Barbería Centro venció")
      expect(calendar(mail)).to be_nil
      expect(text(mail)).to include("Barbería Centro no respondió a tiempo", "Pedir otro turno")
    end
  end

  describe "#rescheduled" do
    it "gives the old and new time, the business's deadline and the risk of losing it" do
      in_business do
        create(:working_hour, professional: appointment.professional, day_of_week: 5, start_time: "09:00", end_time: "18:00")
        appointment.confirm!(by: member)
        appointment.reschedule!(zone.local(2026, 10, 16, 17))
      end

      mail = mailer(last_event).rescheduled

      expect(mail.subject).to eq("Recibimos tu cambio de horario en Barbería Centro")
      expect(text(mail)).to include("Pediste pasar tu turno del vie 16 oct, 15:00 a este horario",
                                    "tiene hasta el jue 15 oct, 08:00 para confirmarlo", "vie 16 oct, 17:00 – 17:30",
                                    "si Barbería Centro rechaza el nuevo o no responde a tiempo, perdés el turno.")
      expect(calendar(mail)).to include("METHOD:CANCEL")
    end
  end

  describe "#reassigned" do
    it "names the new professional" do
      event = in_business do
        other = create(:professional, name: "Sofía Torres", services: [ service ])
        create(:working_hour, professional: other, day_of_week: 5, start_time: "09:00", end_time: "18:00")
        appointment.reassign!(other, by: member)
        appointment.events.last
      end

      mail = mailer(event).reassigned

      expect(mail.subject).to eq("Cambió el profesional de tu turno en Barbería Centro")
      expect(text(mail)).to include("ahora te atiende Sofía Torres. El día y el horario no cambian.", "podés ver el estado del pedido")
      expect(calendar(mail)).to be_nil
    end

    it "brings the updated .ics when the appointment was confirmed" do
      event = in_business do
        other = create(:professional, name: "Sofía Torres", services: [ service ])
        create(:working_hour, professional: other, day_of_week: 5, start_time: "09:00", end_time: "18:00")
        appointment.confirm!(by: member)
        appointment.reassign!(other, by: member)
        appointment.events.last
      end

      expect(calendar(mailer(event).reassigned)).to include("METHOD:PUBLISH", "Profesional: Sofía Torres")
    end
  end

  describe "#reminder" do
    it "reminds the customer of the appointment, with its .ics" do
      in_business { appointment.confirm!(by: member) }
      travel_to(zone.local(2026, 10, 15, 16))

      mail = mailer.reminder

      expect(mail.subject).to eq("Recordatorio: tu turno en Barbería Centro es el vie 16 oct, 15:00")
      expect(text(mail)).to include("Te recordamos tu turno en Barbería Centro el vie 16 oct, 15:00.",
                                    "Para cancelarlo o cambiarlo, contactá a Barbería Centro.")
      expect(calendar(mail)).to include("METHOD:PUBLISH")
    end

    it "isn't sent once the appointment is no longer confirmed" do
      in_business { appointment.cancel!(by: :customer) }

      expect { mailer.reminder.deliver_now }.not_to change(ActionMailer::Base.deliveries, :size)
    end
  end

  describe "sending in the business's name" do
    it "comes from the platform's address with the business's name, and replies go to its contact" do
      mail = mailer.requested

      expect(mail.from).to eq([ "no-reply@bookly.test" ])
      expect(mail[:from].display_names).to eq([ "Barbería Centro" ])
      expect(mail.reply_to).to eq([ "hola@barberia.example" ])
    end

    it "has no reply-to when the business has no contact email" do
      business.update!(contact_email: nil)

      expect(mailer.requested.reply_to).to be_nil
    end

    it "is written in the business's language and time zone, whatever the current ones" do
      business.update!(locale: "en", time_zone: "Europe/Madrid")

      mail = I18n.with_locale(:es) { Time.use_zone("UTC") { mailer.requested.message } }

      expect(mail.subject).to eq("We received your appointment request at Barbería Centro")
      expect(text(mail)).to include("Fri, Oct 16, 8:00 PM – 8:30 PM (Madrid time)")
    end

    it "loads the appointment within the business when delivered by a job, with no current business" do
      appointment

      expect { perform_enqueued_jobs { mailer.requested.deliver_later } }.to change(ActionMailer::Base.deliveries, :size).by(1)
      expect(Current.business).to be_nil
    end
  end
end
