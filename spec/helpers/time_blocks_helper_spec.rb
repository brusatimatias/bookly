require "rails_helper"

RSpec.describe TimeBlocksHelper, type: :helper do
  around do |example|
    with_business(create(:business)) { Time.use_zone("America/Argentina/Buenos_Aires") { example.run } }
  end

  def period(starts_at, ends_at)
    helper.time_block_period(TimeBlock.new(starts_at: starts_at, ends_at: ends_at))
  end

  it "shows the day and both times within a day" do
    expect(period(Time.zone.local(2026, 10, 15, 16), Time.zone.local(2026, 10, 15, 19))).to eq("jue 15 oct, 16:00 – 19:00")
  end

  it "shows the first and last day of whole days" do
    expect(period(Time.zone.local(2026, 10, 20), Time.zone.local(2026, 10, 25))).to eq("mar 20 oct – sáb 24 oct")
  end

  it "shows a single whole day once" do
    expect(period(Time.zone.local(2026, 10, 20), Time.zone.local(2026, 10, 21))).to eq("mar 20 oct")
  end

  it "shows both days and times across days" do
    expect(period(Time.zone.local(2026, 10, 15, 22), Time.zone.local(2026, 10, 16, 8))).to eq("jue 15 oct 22:00 – vie 16 oct 08:00")
  end

  it "follows the locale" do
    I18n.with_locale(:en) do
      expect(period(Time.zone.local(2026, 10, 15, 16), Time.zone.local(2026, 10, 15, 19))).to eq("Thu, Oct 15, 4:00 PM – 7:00 PM")
    end
  end
end
