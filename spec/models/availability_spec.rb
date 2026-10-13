require "rails_helper"

RSpec.describe Availability, type: :model do
  let(:business) do
    create(:business, time_zone: "America/Argentina/Buenos_Aires", slot_interval_minutes: 30,
      min_booking_notice_hours: 2, booking_horizon_days: 60, buffer_minutes: 0)
  end
  let(:zone) { Time.find_zone!(business.time_zone) }
  let(:monday) { Date.new(2026, 10, 19) }
  # The Friday before, in the morning.
  let(:now) { zone.local(2026, 10, 16, 10) }
  let(:service) { create(:service, duration_minutes: 30, buffer_minutes: nil) }
  let(:professional) { create(:professional, name: "Martín", services: [ service ]) }

  around { |example| with_business(business) { example.run } }

  def works(candidate, day_of_week, start_time, end_time)
    create(:working_hour, professional: candidate, day_of_week: day_of_week, start_time: start_time, end_time: end_time)
  end

  def local(date, time)
    hour, minute = time.split(":").map(&:to_i)
    zone.local(date.year, date.month, date.day, hour, minute)
  end

  def times_on(date, **options)
    Availability.new(service, now: now, **options).days(date..date).fetch(date, []).map { |slot| slot.starts_at.strftime("%H:%M") }
  end

  describe "start times" do
    before { works(professional, 1, "09:00", "13:00") }

    it "are counted from the start of each range, every interval, while the service fits" do
      expect(times_on(monday)).to eq(%w[09:00 09:30 10:00 10:30 11:00 11:30 12:00 12:30])
    end

    it "follow the range's start" do
      professional.working_hours.update_all(start_time: "09:15")

      expect(times_on(monday)).to eq(%w[09:15 09:45 10:15 10:45 11:15 11:45 12:15])
    end

    it "follow the business's interval" do
      business.update!(slot_interval_minutes: 60)

      expect(times_on(monday)).to eq(%w[09:00 10:00 11:00 12:00])
    end

    it "need the whole service to fit in the range" do
      service.update!(duration_minutes: 45)

      expect(times_on(monday).last).to eq("12:00")
    end

    it "let the break run past the end of the range" do
      service.update!(buffer_minutes: 15)

      expect(times_on(monday).last).to eq("12:30")
    end

    it "cover every range of the day" do
      works(professional, 1, "14:00", "15:00")

      expect(times_on(monday)).to include("12:30", "14:00", "14:30")
      expect(times_on(monday)).not_to include("13:00", "13:30")
    end

    it "only come from the day's ranges" do
      expect(times_on(monday + 1)).to be_empty
    end

    it "are wall clock times in the business's time zone" do
      slot = Availability.new(service, now: now).days(monday..monday)[monday].first

      expect(slot.starts_at).to eq(local(monday, "09:00"))
      expect(slot.starts_at.utc.hour).to eq(12)
    end
  end

  describe "blocks" do
    before { works(professional, 1, "09:00", "13:00") }

    it "remove the times whose service they overlap" do
      create(:time_block, professional: professional, starts_at: local(monday, "10:00"), ends_at: local(monday, "11:00"))

      expect(times_on(monday)).to eq(%w[09:00 09:30 11:00 11:30 12:00 12:30])
    end

    it "may cover the break after the service" do
      service.update!(buffer_minutes: 30)
      create(:time_block, professional: professional, starts_at: local(monday, "12:30"), ends_at: local(monday, "13:00"))

      expect(times_on(monday).last).to eq("12:00")
    end

    it "remove whole days" do
      create(:time_block, professional: professional, starts_at: local(monday, "00:00"), ends_at: local(monday + 1, "00:00"))

      expect(times_on(monday)).to be_empty
    end
  end

  describe "appointments" do
    before do
      works(professional, 1, "09:00", "13:00")
      service.update!(buffer_minutes: 10)
    end

    def book(time, **attributes)
      create(:appointment, service: service, professional: professional, starts_at: local(monday, time), **attributes)
    end

    it "remove the times whose service or break overlap an active appointment's, both ways" do
      # Busy 10:00-10:40: 09:30 would run its break into it, 10:30 starts inside it.
      book("10:00", status: :confirmed)

      expect(times_on(monday)).to eq(%w[09:00 11:00 11:30 12:00 12:30])
    end

    it "count pending requests, which already hold their time" do
      book("10:00")

      expect(times_on(monday)).not_to include("10:00")
    end

    it "use the business's break for services without one" do
      service.update!(buffer_minutes: nil)
      business.update!(buffer_minutes: 30)
      book("10:00", status: :confirmed)

      # Busy 10:00-11:00 (the appointment copied the business's 30 minutes);
      # 09:30 would end its own break at 10:30.
      expect(times_on(monday)).to eq(%w[09:00 11:00 11:30 12:00 12:30])
    end

    it "free the time once they no longer hold it" do
      book("10:00", status: :cancelled)

      expect(times_on(monday)).to include("09:30", "10:00", "10:30")
    end
  end

  describe "booking window" do
    before do
      works(professional, 1, "09:00", "13:00")
      works(professional, 2, "09:00", "13:00")
    end

    it "starts after the minimum notice" do
      expect(Availability.new(service, now: local(monday, "09:40")).days(monday..monday)[monday].map { |slot| slot.starts_at.strftime("%H:%M") })
        .to eq(%w[12:00 12:30])
    end

    it "ends booking_horizon_days after today, leaving out later days" do
      business.update!(booking_horizon_days: 3)
      availability = Availability.new(service, now: now)

      expect(availability.last_day).to eq(monday)
      expect(availability.days(monday..monday + 1).keys).to eq([ monday ])
    end

    it "leaves out past days" do
      expect(Availability.new(service, now: local(monday + 1, "08:00")).days(monday..monday + 1).keys).to eq([ monday + 1 ])
    end

    it "is empty when the range is outside the window" do
      expect(Availability.new(service, now: now).days((monday - 30)..(monday - 20))).to eq({})
    end

    it "lists every day of the range, even without slots" do
      expect(Availability.new(service, now: now).days(monday - 2..monday).keys).to eq([ monday - 2, monday - 1, monday ])
    end
  end

  describe "professionals" do
    let(:other) { create(:professional, name: "Sofía", services: [ service ]) }

    before do
      works(professional, 1, "09:00", "10:00")
      works(other, 1, "09:30", "10:30")
    end

    it "lists who is free at each time when any professional will do" do
      slots = Availability.new(service, now: now).days(monday..monday)[monday]

      expect(slots.map { |slot| [ slot.starts_at.strftime("%H:%M"), slot.professionals.map(&:name) ] })
        .to eq([ [ "09:00", [ "Martín" ] ], [ "09:30", [ "Martín", "Sofía" ] ], [ "10:00", [ "Sofía" ] ] ])
    end

    it "only looks at the given professional" do
      expect(times_on(monday, professional: other)).to eq(%w[09:30 10:00])
    end

    it "only counts bookable professionals offering the service" do
      other.deactivate!
      works(create(:professional, services: [ create(:service) ]), 1, "11:00", "12:00")

      expect(Availability.new(service, now: now).professionals).to eq([ professional ])
    end

    it "is empty for a professional who doesn't offer the service" do
      stranger = create(:professional, services: [ create(:service) ])
      works(stranger, 1, "09:00", "10:00")

      expect(times_on(monday, professional: stranger)).to be_empty
    end

    it "is empty for an inactive service" do
      service.deactivate!

      expect(Availability.new(service, now: now).days(monday..monday)).to eq({})
    end
  end

  it "needs a current business" do
    Current.set(business: nil) do
      expect { Availability.new(service) }.to raise_error(Current::MissingBusiness)
    end
  end

  describe "daylight saving time" do
    let(:business) { create(:business, time_zone: "America/New_York", min_booking_notice_hours: 0) }
    let(:now) { zone.local(2026, 10, 28, 8) }

    it "keeps the local start times across the change" do
      # Clocks go back on Sunday, November 1st, 2026.
      works(professional, 6, "09:00", "09:30")
      works(professional, 0, "09:00", "09:30")
      days = Availability.new(service, now: now).days(Date.new(2026, 10, 31)..Date.new(2026, 11, 1))

      saturday, sunday = days.values.map(&:first)
      expect([ saturday.starts_at.strftime("%H:%M"), sunday.starts_at.strftime("%H:%M") ]).to eq(%w[09:00 09:00])
      expect([ saturday.starts_at.utc.hour, sunday.starts_at.utc.hour ]).to eq([ 13, 14 ])
    end
  end
end
