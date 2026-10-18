require "rails_helper"

RSpec.describe SetupHours do
  let(:business) { create(:business) }
  let(:ana) { create(:professional, name: "Ana") }
  let(:pablo) { create(:professional, name: "Pablo") }

  around { |example| with_business(business) { example.run } }

  it "defaults to weekdays from 09:00 to 18:00" do
    expect(described_class.new(professionals: [])).to have_attributes(days: [ 1, 2, 3, 4, 5 ], start_time: "09:00", end_time: "18:00")
  end

  it "gives every professional the range on each chosen day" do
    hours = described_class.new({ days: [ "", "1", "3", "6" ], start_time: "10:00", end_time: "14:30" }, professionals: [ ana, pablo ])

    expect(hours.save).to be(true)

    [ ana, pablo ].each do |professional|
      ranges = professional.working_hours.ordered.map { |range| [ range.day_of_week, range.start_time.strftime("%H:%M"), range.end_time.strftime("%H:%M") ] }
      expect(ranges).to eq([ [ 1, "10:00", "14:30" ], [ 3, "10:00", "14:30" ], [ 6, "10:00", "14:30" ] ])
    end
  end

  it "needs a day and a range that ends after it starts" do
    hours = described_class.new({ days: [ "" ], start_time: "18:00", end_time: "09:00" }, professionals: [ ana ])

    expect(hours.save).to be(false)
    expect(hours.errors).to be_of_kind(:days, :blank)
    expect(hours.errors).to be_of_kind(:end_time, :after_start)
    expect(ana.working_hours).to be_empty
  end

  it "rejects times that aren't times" do
    hours = described_class.new({ start_time: "9", end_time: "25:00" }, professionals: [ ana ])

    expect(hours).not_to be_valid
    expect(hours.errors.attribute_names).to contain_exactly(:start_time, :end_time)
  end

  it "saves nothing when a range can't be created" do
    create(:working_hour, professional: pablo, day_of_week: 1, start_time: "08:00", end_time: "12:00")
    hours = described_class.new({ days: [ "1" ] }, professionals: [ ana, pablo ])

    expect { hours.save }.to raise_error(ActiveRecord::RecordInvalid)
    expect(ana.working_hours.reload).to be_empty
  end
end
