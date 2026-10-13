require "rails_helper"

RSpec.describe TimeBlock, type: :model do
  let(:business) { create(:business) }
  let(:professional) { create(:professional) }
  let(:noon) { 1.day.from_now.change(hour: 12) }

  around { |example| with_business(business) { example.run } }

  def block(starts_at, ends_at, **attributes)
    build(:time_block, professional: professional, starts_at: starts_at, ends_at: ends_at, **attributes)
  end

  it "is valid with the factory defaults" do
    expect(build(:time_block)).to be_valid
  end

  it "ends after it starts" do
    time_block = block(noon, noon)

    expect(time_block).not_to be_valid
    expect(time_block.errors).to be_of_kind(:ends_at, :after_start)
    expect { time_block.save(validate: false) }.to raise_error(ActiveRecord::StatementInvalid, /time_blocks_end_after_start/)
  end

  it "requires both ends" do
    time_block = block(nil, nil)

    expect(time_block).not_to be_valid
    expect(time_block.errors).to be_of_kind(:starts_at, :blank)
    expect(time_block.errors).to be_of_kind(:ends_at, :blank)
  end

  it "has an optional, squished reason of up to 100 characters" do
    expect(block(noon, noon + 1.hour, reason: "  Dentist   appointment ").reason).to eq("Dentist appointment")
    expect(block(noon, noon + 1.hour, reason: " ").reason).to be_nil
    expect(block(noon, noon + 1.hour, reason: "a" * 101)).not_to be_valid
  end

  describe "overlaps" do
    before { block(noon, noon + 2.hours).save! }

    it "rejects a block overlapping another one of the same professional" do
      time_block = block(noon + 1.hour, noon + 3.hours)

      expect(time_block).not_to be_valid
      expect(time_block.errors).to be_of_kind(:base, :overlap)
    end

    it "is checked in the database, which reports it as the same error" do
      time_block = block(noon - 1.hour, noon + 1.hour)

      expect(time_block.save(validate: false)).to be(false)
      expect(time_block.errors).to be_of_kind(:base, :overlap)
      expect(time_block).to be_new_record
      expect { time_block.save!(validate: false) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "keeps an outer transaction usable after the database rejects one" do
      TimeBlock.transaction do
        expect(block(noon - 1.hour, noon + 1.hour).save(validate: false)).to be(false)
        expect(block(noon + 3.hours, noon + 4.hours).save).to be(true)
      end
    end

    it "allows blocks that only touch" do
      expect(block(noon + 2.hours, noon + 3.hours)).to be_valid
      expect(block(noon - 1.hour, noon)).to be_valid
    end

    it "allows the same period for another professional" do
      expect(block(noon, noon + 2.hours, professional: create(:professional))).to be_valid
    end

    it "does not count the block itself" do
      time_block = professional.time_blocks.first
      time_block.ends_at = noon + 4.hours

      expect(time_block).to be_valid
    end
  end

  describe ".overlapping" do
    it "finds the blocks that overlap a range, not the ones that only touch it" do
      inside = block(noon, noon + 1.hour).tap(&:save!)
      block(noon + 2.hours, noon + 3.hours).save!

      expect(described_class.overlapping(noon - 1.hour...noon + 2.hours)).to contain_exactly(inside)
    end
  end

  describe ".upcoming" do
    it "lists ongoing and future blocks, soonest first" do
      later = block(noon + 1.day, noon + 1.day + 1.hour).tap(&:save!)
      ongoing = block(1.hour.ago, 1.hour.from_now).tap(&:save!)
      block(3.hours.ago, 2.hours.ago).save!(validate: false)

      expect(described_class.upcoming).to eq([ ongoing, later ])
    end
  end

  describe "whole days" do
    around { |example| Time.use_zone("America/Argentina/Buenos_Aires") { example.run } }

    let(:monday) { Date.new(2026, 10, 19) }

    def whole_days(start_date, end_date)
      block(nil, nil, all_day: true, start_date: start_date, end_date: end_date)
    end

    it "goes from the first day's midnight to the midnight after the last day, in the current time zone" do
      time_block = whole_days(monday, monday + 4).tap(&:save!)

      expect(time_block.starts_at).to eq(Time.zone.local(2026, 10, 19))
      expect(time_block.ends_at).to eq(Time.zone.local(2026, 10, 24))
      expect(time_block.starts_at.utc.hour).to eq(3)
      expect(time_block).to be_whole_days
      expect(time_block.last_day).to eq(monday + 4)
    end

    it "can be a single day" do
      expect(whole_days(monday, monday).tap(&:save!).range).to eq(Time.zone.local(2026, 10, 19)...Time.zone.local(2026, 10, 20))
    end

    it "blocks a single day without an end date" do
      time_block = whole_days(monday, nil).tap(&:save!)

      expect(time_block.range).to eq(Time.zone.local(2026, 10, 19)...Time.zone.local(2026, 10, 20))
    end

    it "requires the first day, and the last not before it" do
      expect(whole_days(nil, nil).tap(&:valid?).errors).to be_of_kind(:start_date, :blank)
      expect(whole_days(monday, monday - 1).tap(&:valid?).errors).to be_of_kind(:end_date, :before_start)
    end

    it "ignores the times of the form" do
      time_block = whole_days(monday, monday)
      time_block.assign_attributes(starts_at: nil, ends_at: nil)

      expect(time_block).to be_valid
    end

    it "fills the days back for the edit form" do
      time_block = TimeBlock.find(whole_days(monday, monday + 2).tap(&:save!).id)

      time_block.assign_dates_from_range

      expect(time_block).to have_attributes(all_day: true, start_date: monday, end_date: monday + 2)
    end

    it "keeps the days of blocks with times, without making them whole days" do
      time_block = block(Time.zone.local(2026, 10, 19, 9), Time.zone.local(2026, 10, 20, 13))

      time_block.assign_dates_from_range

      expect(time_block).to have_attributes(all_day: false, start_date: monday, end_date: monday + 1)
    end
  end

  describe "active appointments" do
    let(:service) { create(:service, duration_minutes: 30, buffer_minutes: 15) }

    before do
      professional.services << service
      create(:appointment, professional: professional, service: service, starts_at: noon, status: :confirmed)
    end

    it "can't be covered by a block" do
      time_block = block(noon - 1.hour, noon + 1.hour)

      expect(time_block).not_to be_valid
      expect(time_block.errors).to be_of_kind(:base, :appointments)
      expect(time_block.errors.full_messages).to include("Se superpone con un turno activo: cancelalo o movelo antes de bloquear")
      expect(time_block.conflicting_appointments.size).to eq(1)
    end

    it "may leave their break inside the block" do
      expect(block(noon + 30.minutes, noon + 2.hours)).to be_valid
    end

    it "don't count once cancelled" do
      Appointment.update_all(status: "cancelled")

      expect(block(noon - 1.hour, noon + 1.hour)).to be_valid
    end

    it "don't stop editing a block whose period doesn't change" do
      time_block = block(noon - 1.hour, noon - 30.minutes).tap(&:save!)
      time_block.update_columns(ends_at: noon + 1.hour)

      time_block.reload.reason = "Trámite"

      expect(time_block).to be_valid
    end
  end

  describe "blocks that already ended" do
    it "can't be created" do
      time_block = block(3.hours.ago, 1.hour.ago)

      expect(time_block).not_to be_valid
      expect(time_block.errors).to be_of_kind(:base, :over)
    end

    it "can't be moved to the past" do
      time_block = block(noon, noon + 1.hour).tap(&:save!)

      time_block.assign_attributes(starts_at: 3.hours.ago, ends_at: 1.hour.ago)

      expect(time_block).not_to be_valid
      expect(time_block.errors).to be_of_kind(:base, :over)
    end

    it "can still be edited once ongoing, keeping its end" do
      time_block = block(1.hour.ago, 1.hour.from_now).tap(&:save!)

      travel 30.minutes do
        time_block.reason = "Trámite"

        expect(time_block).to be_valid
      end
    end
  end

  it "knows when it is ongoing" do
    expect(block(1.hour.ago, 1.hour.from_now)).to be_ongoing
    expect(block(noon, noon + 1.hour)).not_to be_ongoing
  end

  it "belongs to a professional of the same business in the database" do
    other_professional = with_business(create(:business)) { create(:professional) }
    time_block = block(noon, noon + 1.hour, professional_id: other_professional.id, professional: nil)

    expect { time_block.save(validate: false) }.to raise_error(ActiveRecord::InvalidForeignKey)
  end
end
