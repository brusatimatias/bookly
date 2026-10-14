require "rails_helper"

RSpec.describe AppointmentRequest, type: :model do
  let(:business) do
    create(:business, time_zone: "America/Argentina/Buenos_Aires", min_booking_notice_hours: 0, booking_horizon_days: 30,
                      request_expiration_hours: 24)
  end
  let(:zone) { Time.find_zone!(business.time_zone) }
  # A Wednesday morning.
  let(:now) { zone.local(2026, 10, 14, 8) }
  # Thursday 15 at 09:00.
  let(:thursday_nine) { zone.local(2026, 10, 15, 9) }
  let(:service) { create(:service, duration_minutes: 30, buffer_minutes: 0, price_cents: 12_000_00) }
  let(:martin) { create(:professional, name: "Martín Gómez", services: [ service ]) }
  let(:sofia) { create(:professional, name: "Sofía Torres", services: [ service ]) }
  let(:details) { { name: "  Ana  Pérez ", email: " Ana@Example.com ", phone: "11 5555 0101", customer_notes: "Pelo largo" } }

  around { |example| travel_to(now) { with_business(business) { example.run } } }

  before do
    [ martin, sofia ].each { |professional| create(:working_hour, professional: professional, day_of_week: 4, start_time: "09:00", end_time: "12:00") }
  end

  def request_for(professional = nil, starts_at: thursday_nine, **attributes)
    described_class.new(availability: Availability.new(service, professional: professional), starts_at: starts_at, **details, **attributes)
  end

  def book(professional, starts_at, status: :pending)
    create(:appointment, service: service, professional: professional, starts_at: starts_at, status: status)
  end

  it "requires a name and a valid email, and limits the rest" do
    request = request_for(name: " ", email: "nope", phone: "1" * 31, customer_notes: "a" * 501)

    expect(request.save).to be(false)
    expect(request.errors.attribute_names).to contain_exactly(:name, :email, :phone, :customer_notes)
    expect(Appointment.count).to eq(0)
  end

  describe "a successful request" do
    it "creates a pending appointment with the chosen professional, holding the time" do
      request = request_for(sofia)

      expect(request.save).to be(true)
      expect(request.appointment).to be_persisted
      expect(request.appointment).to have_attributes(status: "pending", professional: sofia, service: service, starts_at: thursday_nine,
                                                     any_professional: false, customer_notes: "Pelo largo", price_cents: 12_000_00,
                                                     request_expires_at: now + 24.hours)
    end

    it "creates the customer, normalized" do
      request_for(sofia).save

      expect(Customer.sole).to have_attributes(name: "Ana Pérez", email: "ana@example.com", phone: "11 5555 0101")
    end

    it "records the creation by the customer" do
      appointment = request_for(sofia).tap(&:save).appointment

      expect(appointment.events.sole).to have_attributes(from_status: nil, to_status: "pending", actor_kind: "customer", actor_user: nil)
    end

    it "updates a returning customer with the latest name and phone, keeping the phone when none is given" do
      customer = create(:customer, email: "ana@example.com", name: "Ana", phone: "11 4444 0000")

      request_for(sofia).save
      expect(customer.reload).to have_attributes(name: "Ana Pérez", phone: "11 5555 0101")

      request_for(sofia, starts_at: thursday_nine + 1.hour, name: "Ana P.", phone: "").save
      expect(customer.reload).to have_attributes(name: "Ana P.", phone: "11 5555 0101")
      expect(Customer.count).to eq(1)
    end
  end

  describe "with any professional" do
    it "assigns whoever has the fewest active appointments that day, and marks it" do
      book(martin, thursday_nine + 1.hour)
      book(sofia, thursday_nine + 2.hours, status: :cancelled)

      appointment = request_for.tap(&:save).appointment

      expect(appointment).to have_attributes(professional: sofia, any_professional: true)
    end

    it "breaks ties by name" do
      expect(request_for.tap(&:save).appointment.professional).to eq(martin)
    end

    it "assigns the only one free at that time" do
      book(martin, thursday_nine)

      expect(request_for.tap(&:save).appointment.professional).to eq(sofia)
    end

    it "tries the next free professional when the first was just taken" do
      book(martin, thursday_nine)
      2.times { |hour| book(sofia, thursday_nine + (hour + 1).hours) }
      request = request_for
      # As if Martín was still free when the slot was read.
      stale = { thursday_nine.to_date => [ Availability::Slot.new(starts_at: thursday_nine, professionals: [ martin, sofia ]) ] }
      allow(request.availability).to receive(:days).and_return(stale)

      expect(request.save).to be(true)
      expect(request.appointment.professional).to eq(sofia)
    end
  end

  describe "a time no longer free" do
    it "is rejected when someone took it" do
      book(sofia, thursday_nine)
      request = request_for(sofia)

      expect(request.save).to be(false)
      expect(request).to be_slot_taken
      expect(Customer.exists?(email: "ana@example.com")).to be(false)
    end

    it "is rejected when the database refuses it, leaving nothing behind" do
      book(sofia, thursday_nine)
      request = request_for(sofia)
      stale = { thursday_nine.to_date => [ Availability::Slot.new(starts_at: thursday_nine, professionals: [ sofia ]) ] }
      allow(request.availability).to receive(:days).and_return(stale)

      expect(request.save).to be(false)
      expect(request).to be_slot_taken
      expect(Customer.exists?(email: "ana@example.com")).to be(false)
      expect(AppointmentEvent.count).to eq(0)
    end

    it "is rejected when a block covers it" do
      create(:time_block, professional: sofia, starts_at: thursday_nine, ends_at: thursday_nine + 1.hour)

      expect(request_for(sofia)).to have_attributes(save: false, slot_taken?: true)
    end

    it "is rejected when it isn't a slot" do
      expect(request_for(sofia, starts_at: thursday_nine + 5.minutes)).to have_attributes(save: false, slot_taken?: true)
    end
  end

  it "rejects a customer's second appointment at the same time, with another professional" do
    customer = create(:customer, email: "ana@example.com")
    create(:appointment, service: service, professional: martin, customer: customer, starts_at: thursday_nine + 15.minutes)
    request = request_for(sofia)

    expect(request.save).to be(false)
    expect(request.errors).to be_added(:base, :overlaps_own_appointment)
    expect(request).not_to be_slot_taken
    expect(customer.reload.name).not_to eq("Ana Pérez")
  end

  it "allows the customer's appointments one after another" do
    customer = create(:customer, email: "ana@example.com")
    create(:appointment, service: service, professional: martin, customer: customer, starts_at: thursday_nine - 30.minutes, status: :confirmed)

    expect(request_for(sofia).save).to be(true)
  end
end
