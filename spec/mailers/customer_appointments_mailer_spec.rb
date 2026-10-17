require "rails_helper"

RSpec.describe CustomerAppointmentsMailer, type: :mailer do
  let(:business) do
    create(:business, name: "Barbería Centro", time_zone: "America/Argentina/Buenos_Aires", request_expiration_hours: 24,
                      contact_email: "hola@barberia.example", address: "Av. Corrientes 1234")
  end
  let(:zone) { Time.find_zone!(business.time_zone) }
  let(:appointment) do
    with_business(business) do
      service = create(:service, name: "Corte de pelo", duration_minutes: 30, price_cents: 12_000_00)
      create(:appointment, service: service, professional: create(:professional, name: "Martín Gómez", services: [ service ]),
                           customer: create(:customer, name: "Ana Pérez", email: "ana@example.com"), starts_at: zone.local(2026, 10, 16, 15))
    end
  end

  # A Wednesday morning.
  around { |example| travel_to(zone.local(2026, 10, 14, 8)) { example.run } }

  def mailer
    described_class.with(business: business, appointment_id: appointment.id)
  end

  describe "#requested" do
    it "tells the customer the business has to confirm, with the details and their link" do
      mail = mailer.requested

      expect(mail.to).to eq([ "ana@example.com" ])
      expect(mail.subject).to eq("Recibimos tu pedido de turno en Barbería Centro")
      expect(mail.text_part.body.to_s).to include("Hola, Ana Pérez:", "Barbería Centro tiene hasta el jue 15 oct, 08:00 para confirmarlo.",
                                                  "vie 16 oct, 15:00 – 15:30 (Hora de Buenos Aires)", "Corte de pelo (30 min · $ 12.000)",
                                                  "Martín Gómez", "Av. Corrientes 1234")
      expect(mail.html_part.body.to_s).to include("Ver mi turno", MailerHelper::BRAND_COLOR)

      token = mail.text_part.body.to_s[%r{/appointments/(\S+)}, 1]
      expect(with_business(business) { Appointment.find_by_token_for(:management, token) }).to eq(appointment)
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
      expect(mail.text_part.body.to_s).to include("Fri, Oct 16, 8:00 PM – 8:30 PM (Madrid time)")
    end

    it "loads the appointment within the business when delivered by a job, with no current business" do
      appointment

      expect { perform_enqueued_jobs { mailer.requested.deliver_later } }.to change(ActionMailer::Base.deliveries, :size).by(1)
      expect(Current.business).to be_nil
    end
  end
end
