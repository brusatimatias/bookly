require "rails_helper"

RSpec.describe StatsPeriod, type: :model do
  let(:zone) { Time.find_zone!("America/Argentina/Buenos_Aires") }
  # A Wednesday.
  let(:now) { zone.local(2026, 10, 21, 12) }

  def period(key, at: now)
    described_class.new(key, zone: zone, now: at)
  end

  it "covers this month's whole days, in the time zone" do
    this_month = period("this_month")

    expect(this_month.days).to eq(Date.new(2026, 10, 1)..Date.new(2026, 10, 31))
    expect(this_month.range).to eq(zone.local(2026, 10, 1)...zone.local(2026, 11, 1))
    expect(this_month.range.begin.utc.hour).to eq(3)
    expect(this_month).to be_current
    expect(this_month.cache_key).to eq("this_month/2026-10-01")
  end

  it "covers last month, already over" do
    last_month = period("last_month")

    expect(last_month.days).to eq(Date.new(2026, 9, 1)..Date.new(2026, 9, 30))
    expect(last_month).not_to be_current
    expect(last_month.cache_key).to eq("last_month/2026-09-01")
  end

  it "covers the last 90 days, today included" do
    last_90_days = period("last_90_days")

    expect(last_90_days.days.count).to eq(90)
    expect(last_90_days.days.last).to eq(Date.new(2026, 10, 21))
    expect(last_90_days).to be_current
    expect(last_90_days.cache_key).to eq("last_90_days/2026-07-24")
  end

  it "takes today from the time zone, not from UTC" do
    # Already November in UTC, still October 31 in Buenos Aires.
    expect(period("this_month", at: Time.utc(2026, 11, 1, 1)).days.first).to eq(Date.new(2026, 10, 1))
  end

  it "falls back to this month for an unknown key" do
    expect(period("forever").key).to eq("this_month")
    expect(period(nil).key).to eq("this_month")
  end
end
