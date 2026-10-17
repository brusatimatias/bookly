require "rails_helper"

RSpec.describe SendRemindersJob, type: :job do
  include ActiveJob::TestHelper

  let(:business) { create(:business, time_zone: "America/Argentina/Buenos_Aires", reminder_hours_before: 24) }
  let(:zone) { Time.find_zone!(business.time_zone) }
  # Friday at 15:00: its reminder is due on Thursday at 15:00.
  let(:starts_at) { zone.local(2026, 10, 16, 15) }

  # A Wednesday morning.
  around { |example| travel_to(zone.local(2026, 10, 14, 8)) { example.run } }

  def appointment_in(business, status: :confirmed, **attributes)
    with_business(business) { create(:appointment, status: status, starts_at: starts_at, **attributes) }
  end

  # The appointments the enqueued reminders are about.
  def reminded
    enqueued_jobs.select { |job| job["arguments"].first(2) == [ "CustomerAppointmentsMailer", "reminder" ] }
      .map { |job| ActiveJob::Arguments.deserialize(job["arguments"]).last.dig(:params, :appointment_id) }
  end

  it "reminds the customers of every business once their reminder is due, each within its own" do
    appointment = appointment_in(business)
    other_business = create(:business, reminder_hours_before: 2)
    other = appointment_in(other_business, starts_at: starts_at)

    travel_to(zone.local(2026, 10, 15, 14, 59))

    described_class.perform_now
    expect(reminded).to be_empty

    travel_to(zone.local(2026, 10, 15, 15))

    described_class.perform_now
    expect(reminded).to eq([ appointment.id ])
    expect(with_business(business) { appointment.reload.reminder_sent_at }).to eq(zone.local(2026, 10, 15, 15))

    travel_to(zone.local(2026, 10, 16, 13))

    described_class.perform_now
    expect(reminded).to eq([ appointment.id, other.id ])
  end

  it "never reminds twice" do
    appointment_in(business)

    travel_to(zone.local(2026, 10, 15, 16))
    described_class.perform_now
    described_class.perform_now

    expect(reminded.size).to eq(1)
  end

  it "delivers the reminder" do
    appointment_in(business)

    travel_to(zone.local(2026, 10, 15, 16))

    expect { perform_enqueued_jobs { described_class.perform_now } }.to change(ActionMailer::Base.deliveries, :size).by(1)
    expect(ActionMailer::Base.deliveries.last.subject).to start_with("Recordatorio")
  end

  it "leaves requests, cancelled appointments and ones that started" do
    appointment_in(business, status: :pending)
    appointment_in(business, status: :cancelled, starts_at: starts_at + 1.hour)
    appointment_in(business, starts_at: zone.local(2026, 10, 15, 9))

    travel_to(zone.local(2026, 10, 15, 16))

    described_class.perform_now

    expect(reminded).to be_empty
  end

  it "sends none when the business turned them off or is suspended" do
    appointment_in(business)
    business.update!(reminder_hours_before: 0)
    appointment_in(create(:business, :suspended), starts_at: starts_at)

    travel_to(zone.local(2026, 10, 15, 16))

    described_class.perform_now

    expect(reminded).to be_empty
  end

  it "sends none for an appointment confirmed after its reminder was due: the confirmation just told the customer" do
    business.update!(request_expiration_hours: 48)
    appointment = appointment_in(business, status: :pending)
    travel_to(zone.local(2026, 10, 15, 16))
    with_business(business) { appointment.confirm!(by: create(:user)) }

    described_class.perform_now

    expect(reminded).to be_empty
  end

  it "reminds one confirmed before its reminder was due" do
    appointment = appointment_in(business, status: :pending)
    with_business(business) { appointment.confirm!(by: create(:user)) }

    travel_to(zone.local(2026, 10, 15, 16))

    described_class.perform_now

    expect(reminded).to eq([ appointment.id ])
  end
end
