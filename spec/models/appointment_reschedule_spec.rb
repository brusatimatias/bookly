require "rails_helper"

RSpec.describe AppointmentReschedule, type: :model do
  let(:business) do
    create(:business, time_zone: "America/Argentina/Buenos_Aires", min_booking_notice_hours: 0, booking_horizon_days: 30,
                      cancellation_window_hours: 24, request_expiration_hours: 24)
  end
  let(:zone) { Time.find_zone!(business.time_zone) }
  # A Monday morning.
  let(:now) { zone.local(2026, 10, 12, 8) }
  # Thursday 15 at 09:00.
  let(:thursday_nine) { zone.local(2026, 10, 15, 9) }
  let(:service) { create(:service, duration_minutes: 30, buffer_minutes: 0) }
  let(:martin) { create(:professional, name: "Martín Gómez", services: [ service ]) }
  let(:sofia) { create(:professional, name: "Sofía Torres", services: [ service ]) }
  let(:customer) { create(:customer) }
  let(:appointment) { book(martin, thursday_nine, customer: customer, status: :confirmed) }

  around { |example| travel_to(now) { with_business(business) { example.run } } }

  before do
    [ martin, sofia ].each { |professional| create(:working_hour, professional: professional, day_of_week: 4, start_time: "09:00", end_time: "12:00") }
  end

  def book(professional, starts_at, status: :pending, **attributes)
    create(:appointment, service: service, professional: professional, starts_at: starts_at, status: status, **attributes)
  end

  def reschedule(starts_at, professional: martin)
    described_class.new(appointment: appointment, availability: Availability.new(service, professional: professional, except: appointment),
                        starts_at: starts_at)
  end

  it "moves the appointment to a free time, back to pending" do
    expect(reschedule(thursday_nine + 2.hours).save).to be(true)

    expect(appointment.reload).to have_attributes(status: "pending", starts_at: thursday_nine + 2.hours, professional: martin)
  end

  it "can move to a time overlapping its own" do
    expect(reschedule(thursday_nine + 30.minutes).save).to be(true)
  end

  it "with any professional, goes to the least busy one free" do
    book(martin, thursday_nine + 1.hour)

    expect(reschedule(thursday_nine + 2.hours, professional: nil).save).to be(true)
    expect(appointment.reload.professional).to eq(sofia)
  end

  it "rejects a time someone else took" do
    book(martin, thursday_nine + 2.hours)
    rescheduling = reschedule(thursday_nine + 2.hours)

    expect(rescheduling.save).to be(false)
    expect(rescheduling).to be_slot_taken
    expect(appointment.reload).to have_attributes(status: "confirmed", starts_at: thursday_nine)
  end

  it "tries the next free professional when the database rejects the first, and gives up when none is left" do
    rescheduling = reschedule(thursday_nine + 2.hours, professional: nil)
    stale = { thursday_nine.to_date => [ Availability::Slot.new(starts_at: thursday_nine + 2.hours, professionals: [ martin, sofia ]) ] }
    allow(rescheduling.availability).to receive(:days).and_return(stale)
    book(martin, thursday_nine + 2.hours)

    expect(rescheduling.save).to be(true)
    expect(appointment.reload.professional).to eq(sofia)

    appointment.update_columns(status: "confirmed", starts_at: thursday_nine, ends_at: thursday_nine + 30.minutes,
                               buffer_ends_at: thursday_nine + 30.minutes, professional_id: martin.id)
    book(sofia, thursday_nine + 2.hours)
    expect(rescheduling.save).to be(false)
    expect(rescheduling).to be_slot_taken
    expect(appointment.reload).to have_attributes(status: "confirmed", starts_at: thursday_nine, professional: martin)
  end

  it "rejects a time that isn't free" do
    expect(reschedule(thursday_nine + 10.minutes).save).to be(false)
    expect(reschedule(zone.local(2026, 10, 15, 13)).save).to be(false)
  end

  it "rejects a time overlapping another of the customer's appointments" do
    book(sofia, thursday_nine + 2.hours, customer: customer)
    rescheduling = reschedule(thursday_nine + 2.hours)

    expect(rescheduling.save).to be(false)
    expect(rescheduling.errors).to be_added(:base, :overlaps_own_appointment)
  end

  it "raises once the appointment can't be rescheduled" do
    appointment
    travel_to(thursday_nine - 23.hours)

    expect { reschedule(thursday_nine + 2.hours).save }.to raise_error(Appointment::InvalidTransition)
  end
end
