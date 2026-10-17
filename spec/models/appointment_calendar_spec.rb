require "rails_helper"

RSpec.describe AppointmentCalendar, type: :model do
  let(:business) { create(:business, name: "Barbería Centro", time_zone: "America/Argentina/Buenos_Aires", address: "Av. Corrientes 1234, CABA") }
  let(:zone) { Time.find_zone!(business.time_zone) }
  let(:appointment) do
    with_business(business) do
      service = create(:service, name: "Corte de pelo", duration_minutes: 30)
      create(:appointment, service: service, professional: create(:professional, name: "Martín Gómez", services: [ service ]),
                           starts_at: zone.local(2026, 10, 16, 15))
    end
  end

  around { |example| travel_to(zone.local(2026, 10, 14, 8)) { with_business(business) { example.run } } }

  def ical(**options)
    described_class.new(appointment, url: "https://bookly.test/barberia-centro/appointments/abc", **options).to_ical
  end

  # The value of a property, with long lines unfolded.
  def property(ical, name)
    ical.gsub("\r\n ", "")[/^#{name}[:;](.*)\r$/, 1]
  end

  it "is the appointment as a confirmed event, in UTC" do
    ics = ical

    expect(property(ics, "METHOD")).to eq("PUBLISH")
    expect(property(ics, "DTSTART")).to eq("20261016T180000Z")
    expect(property(ics, "DTEND")).to eq("20261016T183000Z")
    expect(property(ics, "SUMMARY")).to eq("Corte de pelo – Barbería Centro")
    expect(property(ics, "LOCATION")).to eq("Av. Corrientes 1234\\, CABA")
    expect(property(ics, "DESCRIPTION")).to eq("Profesional: Martín Gómez\\nVer\\, cancelar o cambiar el turno: https://bookly.test/barberia-centro/appointments/abc")
    expect(property(ics, "STATUS")).to eq("CONFIRMED")
    expect(property(ics, "ORGANIZER")).to eq("CN=Barbería Centro:mailto:no-reply@bookly.test")
  end

  it "keeps its UID and raises its SEQUENCE as the appointment changes, so calendars update it" do
    first = ical
    appointment.confirm!(by: create(:user))
    second = ical

    expect(property(second, "UID")).to eq(property(first, "UID")).and eq("bookly-appointment-#{appointment.id}@bookly.test")
    expect(property(second, "SEQUENCE").to_i).to be > property(first, "SEQUENCE").to_i
  end

  it "cancels the event" do
    ics = ical(cancelled: true)

    expect(property(ics, "METHOD")).to eq("CANCEL")
    expect(property(ics, "STATUS")).to eq("CANCELLED")
  end

  it "has no location when the business has no address" do
    business.update!(address: nil)

    expect(property(ical, "LOCATION")).to be_nil
  end

  it "is named and written in the current locale" do
    I18n.with_locale(:en) do
      expect(described_class.new(appointment, url: "x").filename).to eq("appointment.ics")
      expect(property(ical, "DESCRIPTION")).to start_with("Professional: Martín Gómez")
    end
  end
end
