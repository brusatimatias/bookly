require "rails_helper"

RSpec.describe WeeklySchedule, type: :model do
  let(:business) { create(:business) }
  let(:professional) { create(:professional) }

  around { |example| with_business(business) { example.run } }

  def schedule
    described_class.new(professional.reload)
  end

  def saved_ranges
    professional.working_hours.ordered.map { |range| [ range.day_of_week, range.start_time.strftime("%H:%M"), range.end_time.strftime("%H:%M") ] }
  end

  it "groups the current ranges by day, in order" do
    create(:working_hour, professional: professional, day_of_week: 1, start_time: "14:00", end_time: "18:00")
    morning = create(:working_hour, professional: professional, day_of_week: 1, start_time: "09:00", end_time: "13:00")

    expect(schedule.ranges_on(1).first).to eq(morning)
    expect(schedule.ranges_on(2)).to be_empty
  end

  it "shows the week Monday first" do
    expect(described_class::DAYS).to eq([ 1, 2, 3, 4, 5, 6, 0 ])
  end

  describe "#update" do
    before { create(:working_hour, professional: professional, day_of_week: 1, start_time: "09:00", end_time: "13:00") }

    it "replaces the whole week" do
      expect(schedule.update([
        { day_of_week: "2", start_time: "14:00", end_time: "18:00" },
        { day_of_week: "2", start_time: "09:00", end_time: "13:00" },
        { day_of_week: "6", start_time: "10:00", end_time: "12:00" }
      ])).to be(true)

      expect(saved_ranges).to eq([ [ 2, "09:00", "13:00" ], [ 2, "14:00", "18:00" ], [ 6, "10:00", "12:00" ] ])
    end

    it "clears the week when there are no ranges" do
      expect(schedule.update([])).to be(true)

      expect(saved_ranges).to be_empty
    end

    it "skips rows without times" do
      schedule.update([ { day_of_week: "3", start_time: "", end_time: "" } ])

      expect(saved_ranges).to be_empty
    end

    it "keeps the week as it was when a range is invalid" do
      week = schedule

      expect(week.update([
        { day_of_week: "2", start_time: "09:00", end_time: "13:00" },
        { day_of_week: "3", start_time: "18:00", end_time: "10:00" }
      ])).to be(false)

      expect(saved_ranges).to eq([ [ 1, "09:00", "13:00" ] ])
      expect(week.errors).to be_of_kind(:base, :invalid_ranges)
      expect(week.ranges_on(3).first.errors).to be_of_kind(:end_time, :after_start)
      expect(week.ranges_on(2).first).to be_new_record
    end

    it "marks the later of two overlapping ranges" do
      week = schedule

      expect(week.update([
        { day_of_week: "1", start_time: "12:00", end_time: "15:00" },
        { day_of_week: "1", start_time: "09:00", end_time: "13:00" }
      ])).to be(false)

      first, second = week.ranges_on(1)
      expect(first.errors).to be_empty
      expect(second.errors).to be_of_kind(:base, :overlap)
      expect(saved_ranges).to eq([ [ 1, "09:00", "13:00" ] ])
    end

    it "accepts ranges that only touch" do
      expect(schedule.update([
        { day_of_week: "1", start_time: "09:00", end_time: "13:00" },
        { day_of_week: "1", start_time: "13:00", end_time: "17:00" }
      ])).to be(true)
    end
  end
end
