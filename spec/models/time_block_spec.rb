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

    it "is checked in the database" do
      expect { block(noon - 1.hour, noon + 1.hour).save(validate: false) }.to raise_error(ActiveRecord::StatementInvalid, /time_blocks_no_overlap/)
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
      block(3.hours.ago, 2.hours.ago).save!

      expect(described_class.upcoming).to eq([ ongoing, later ])
    end
  end

  it "belongs to a professional of the same business in the database" do
    other_professional = with_business(create(:business)) { create(:professional) }
    time_block = block(noon, noon + 1.hour, professional_id: other_professional.id, professional: nil)

    expect { time_block.save(validate: false) }.to raise_error(ActiveRecord::InvalidForeignKey)
  end
end
