require "rails_helper"

RSpec.describe BusinessStats, type: :model do
  let(:business) { create(:business, time_zone: "America/Argentina/Buenos_Aires") }
  let(:zone) { Time.find_zone!(business.time_zone) }
  # A Wednesday; October 2026 is the current month.
  let(:now) { zone.local(2026, 10, 21, 12) }
  let(:owner) { create(:membership, :owner, business: business) }
  let(:member) { create(:membership, business: business) }
  let(:haircut) { create(:service, name: "Haircut", price_cents: 1_000_00) }
  let(:beard) { create(:service, name: "Beard", price_cents: 500_00) }
  let(:martin) { create(:professional, name: "Martín", user: member.user, services: [ haircut, beard ]) }
  let(:lucia) { create(:professional, name: "Lucía", services: [ haircut, beard ]) }

  around { |example| with_business(business) { AppointmentNotifier.silence { example.run } } }
  before { travel_to now }

  def stats(membership = owner, key = "this_month")
    described_class.new(membership, StatsPeriod.new(key, zone: zone)).to_h
  end

  def appointment(status, starts_at, professional: martin, service: haircut, customer: create(:customer))
    create(:appointment, status: status, starts_at: starts_at, professional: professional, service: service, customer: customer)
  end

  describe "outcomes" do
    it "counts the period's appointments in each status, by their start in the time zone" do
      appointment(:attended, zone.local(2026, 10, 1, 0, 0))
      appointment(:no_show, zone.local(2026, 10, 5, 10))
      appointment(:confirmed, zone.local(2026, 10, 31, 23, 30))
      appointment(:cancelled, zone.local(2026, 10, 30, 10))
      appointment(:attended, zone.local(2026, 9, 30, 23, 30))
      appointment(:attended, zone.local(2026, 11, 1, 0, 0))

      expect(stats[:outcomes]).to eq("pending" => 0, "confirmed" => 1, "rejected" => 0, "expired" => 0,
        "cancelled" => 1, "attended" => 1, "no_show" => 1)
    end

    it "gives the share of missed appointments among the ones with attendance" do
      3.times { |day| appointment(:attended, zone.local(2026, 10, 5 + day, 10)) }
      appointment(:no_show, zone.local(2026, 10, 9, 10))
      appointment(:cancelled, zone.local(2026, 10, 10, 10))

      expect(stats[:no_show_rate]).to eq(0.25)
    end

    it "has no rate without attendance" do
      appointment(:confirmed, zone.local(2026, 10, 25, 10))

      expect(stats[:no_show_rate]).to be_nil
    end
  end

  describe "revenue" do
    it "adds the copied price of the attended appointments" do
      appointment(:attended, zone.local(2026, 10, 5, 10))
      appointment(:attended, zone.local(2026, 10, 6, 10), service: beard)
      appointment(:no_show, zone.local(2026, 10, 7, 10))
      appointment(:confirmed, zone.local(2026, 10, 25, 10))
      haircut.update!(price_cents: 2_000_00)

      expect(stats[:revenue_cents]).to eq(1_500_00)
    end
  end

  describe "top services" do
    it "lists the most requested services, with what their attended appointments made" do
      appointment(:attended, zone.local(2026, 10, 5, 10), service: beard)
      appointment(:cancelled, zone.local(2026, 10, 6, 10), service: beard)
      appointment(:attended, zone.local(2026, 10, 7, 10))

      expect(stats[:top_services]).to eq([
        { name: "Beard", count: 2, revenue_cents: 500_00 },
        { name: "Haircut", count: 1, revenue_cents: 1_000_00 }
      ])
    end
  end

  describe "occupancy" do
    before do
      # Mondays 09:00-13:00: four Mondays in October 2026, 960 minutes.
      create(:working_hour, professional: martin, day_of_week: 1, start_time: "09:00", end_time: "13:00")
      create(:time_block, professional: martin, starts_at: zone.local(2026, 10, 26, 12), ends_at: zone.local(2026, 10, 26, 14))
    end

    it "compares the booked minutes with the working minutes, less the blocks" do
      appointment(:attended, zone.local(2026, 10, 5, 10))
      appointment(:confirmed, zone.local(2026, 10, 26, 9))
      appointment(:cancelled, zone.local(2026, 10, 12, 10))

      expect(stats[:occupancy]).to include({ name: "Martín", booked_minutes: 60, available_minutes: 900, rate: 60.0 / 900 })
    end

    it "lists active professionals, and inactive ones with appointments in the period" do
      create(:professional, :inactive, name: "Gone")
      appointment(:attended, zone.local(2026, 10, 5, 10), professional: create(:professional, :inactive, name: "Left", services: [ haircut ]))
      lucia

      expect(stats[:occupancy].pluck(:name)).to eq(%w[Left Lucía Martín])
      expect(stats[:occupancy].find { |row| row[:name] == "Lucía" }).to include(available_minutes: 0, rate: nil)
    end
  end

  describe "peak hours" do
    it "counts the booked appointments by local weekday and hour" do
      appointment(:attended, zone.local(2026, 10, 5, 10))
      appointment(:confirmed, zone.local(2026, 10, 26, 10, 30))
      appointment(:attended, zone.local(2026, 10, 3, 21), professional: lucia)
      appointment(:cancelled, zone.local(2026, 10, 12, 10))

      expect(stats[:peak_hours]).to eq({ [ 1, 10 ] => 2, [ 6, 21 ] => 1 })
    end
  end

  describe "customers" do
    it "tells new customers from returning ones" do
      returning = create(:customer)
      appointment(:attended, zone.local(2026, 9, 7, 10), customer: returning)
      appointment(:attended, zone.local(2026, 10, 5, 10), customer: returning)
      newcomer = create(:customer)
      appointment(:attended, zone.local(2026, 10, 6, 10), customer: newcomer)
      appointment(:confirmed, zone.local(2026, 10, 27, 10), customer: newcomer)
      appointment(:cancelled, zone.local(2026, 10, 7, 10))

      expect(stats[:customers]).to eq(new: 1, returning: 1)
    end
  end

  describe "response time" do
    def event(appointment, from, to, at, by: owner.user, **attributes)
      actor = by.is_a?(User) ? { actor_kind: :user, actor_user: by } : { actor_kind: by }
      AppointmentEvent.create!(appointment: appointment, from_status: from, to_status: to, created_at: at, **actor, **attributes)
    end

    it "is the median time the team took to answer, from the moment the appointment became pending" do
      confirmed = appointment(:confirmed, zone.local(2026, 10, 27, 10))
      event(confirmed, nil, "pending", zone.local(2026, 10, 2, 9), by: :customer)
      event(confirmed, "pending", "confirmed", zone.local(2026, 10, 2, 11))
      # A reassignment keeps it pending: the clock goes on.
      rejected = appointment(:rejected, zone.local(2026, 10, 28, 10))
      event(rejected, nil, "pending", zone.local(2026, 10, 3, 9), by: :customer)
      event(rejected, "pending", "pending", zone.local(2026, 10, 3, 10), metadata: { to_professional_id: lucia.id })
      event(rejected, "pending", "rejected", zone.local(2026, 10, 3, 13), note: "Closed")

      expect(stats[:response_time]).to eq(answered: 2, median_seconds: 3.hours.to_i)
    end

    it "counts a customer's change of time from the moment they asked for it" do
      rescheduled = appointment(:confirmed, zone.local(2026, 10, 29, 10))
      event(rescheduled, nil, "pending", zone.local(2026, 9, 20, 9), by: :customer)
      event(rescheduled, "pending", "confirmed", zone.local(2026, 9, 20, 10))
      event(rescheduled, "confirmed", "pending", zone.local(2026, 10, 4, 9), by: :customer)
      event(rescheduled, "pending", "confirmed", zone.local(2026, 10, 4, 9, 30))

      expect(stats[:response_time]).to eq(answered: 1, median_seconds: 30.minutes.to_i)
    end

    it "leaves out expired requests, the customer's withdrawals and answers outside the period" do
      expired = appointment(:expired, zone.local(2026, 10, 27, 10))
      event(expired, nil, "pending", zone.local(2026, 10, 2, 9), by: :customer)
      event(expired, "pending", "expired", zone.local(2026, 10, 3, 9), by: :system)
      withdrawn = appointment(:cancelled, zone.local(2026, 10, 28, 10))
      event(withdrawn, nil, "pending", zone.local(2026, 10, 2, 9), by: :customer)
      event(withdrawn, "pending", "cancelled", zone.local(2026, 10, 2, 10), by: :customer)
      earlier = appointment(:confirmed, zone.local(2026, 10, 29, 10))
      event(earlier, nil, "pending", zone.local(2026, 9, 30, 9), by: :customer)
      event(earlier, "pending", "confirmed", zone.local(2026, 9, 30, 10))

      expect(stats[:response_time]).to eq(answered: 0, median_seconds: nil)
    end
  end

  describe "what each member sees" do
    before do
      create(:working_hour, professional: martin)
      create(:working_hour, professional: lucia)
      appointment(:attended, zone.local(2026, 10, 5, 10))
      appointment(:attended, zone.local(2026, 10, 5, 10), professional: lucia)
    end

    it "gives owners and admins the whole business" do
      admin = create(:membership, :admin, business: business)

      expect(stats(owner)[:outcomes]["attended"]).to eq(2)
      expect(stats(admin)[:occupancy].pluck(:name)).to eq(%w[Lucía Martín])
    end

    it "gives professionals their own appointments only" do
      own = stats(member)

      expect(own[:outcomes]["attended"]).to eq(1)
      expect(own[:revenue_cents]).to eq(1_000_00)
      expect(own[:occupancy].pluck(:name)).to eq(%w[Martín])
    end

    it "gives a professional without a profile nothing" do
      unlinked = create(:membership, business: business)

      expect(stats(unlinked)).to include(revenue_cents: 0, occupancy: [], top_services: [], customers: { new: 0, returning: 0 })
    end

    it "leaves out other businesses" do
      other = create(:business)
      with_business(other) { create(:appointment, status: :attended, starts_at: zone.local(2026, 10, 6, 10)) }

      expect(stats[:outcomes]["attended"]).to eq(2)
    end
  end
end
