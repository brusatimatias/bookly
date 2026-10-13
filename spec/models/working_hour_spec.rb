require "rails_helper"

RSpec.describe WorkingHour, type: :model do
  let(:business) { create(:business) }
  let(:professional) { create(:professional) }

  around { |example| with_business(business) { example.run } }

  def range(start_time, end_time, day_of_week: 1, **attributes)
    build(:working_hour, professional: professional, day_of_week: day_of_week, start_time: start_time, end_time: end_time, **attributes)
  end

  it "is valid with the factory defaults" do
    expect(build(:working_hour)).to be_valid
  end

  it "only takes days from 0 (Sunday) to 6" do
    working_hour = range("09:00", "13:00", day_of_week: 7)

    expect(working_hour).not_to be_valid
    expect(working_hour.errors).to be_of_kind(:day_of_week, :inclusion)
    expect { working_hour.save(validate: false) }.to raise_error(ActiveRecord::StatementInvalid, /working_hours_day_of_week_valid/)
  end

  it "ends after it starts" do
    working_hour = range("13:00", "09:00")

    expect(working_hour).not_to be_valid
    expect(working_hour.errors).to be_of_kind(:end_time, :after_start)
    expect { working_hour.save(validate: false) }.to raise_error(ActiveRecord::StatementInvalid, /working_hours_end_after_start/)
  end

  it "requires both times" do
    working_hour = range(nil, nil)

    expect(working_hour).not_to be_valid
    expect(working_hour.errors).to be_of_kind(:start_time, :blank)
    expect(working_hour.errors).to be_of_kind(:end_time, :blank)
  end

  describe "overlaps" do
    before { range("09:00", "13:00").save! }

    it "rejects a range overlapping another one of the same day" do
      working_hour = range("12:00", "15:00")

      expect(working_hour).not_to be_valid
      expect(working_hour.errors).to be_of_kind(:base, :overlap)
    end

    it "is checked in the database" do
      expect { range("10:00", "11:00").save(validate: false) }.to raise_error(ActiveRecord::StatementInvalid, /working_hours_no_overlap/)
    end

    it "allows ranges that only touch" do
      expect(range("13:00", "17:00")).to be_valid
    end

    it "allows the same range on another day or for another professional" do
      expect(range("09:00", "13:00", day_of_week: 2)).to be_valid
      expect(range("09:00", "13:00", professional: create(:professional))).to be_valid
    end

    it "does not count the range itself" do
      working_hour = professional.working_hours.first
      working_hour.end_time = "14:00"

      expect(working_hour).to be_valid
    end
  end

  it "belongs to a professional of the same business in the database" do
    other_professional = with_business(create(:business)) { create(:professional) }
    working_hour = range("09:00", "13:00", professional_id: other_professional.id, professional: nil)

    expect { working_hour.save(validate: false) }.to raise_error(ActiveRecord::InvalidForeignKey)
  end
end
