require "rails_helper"

RSpec.describe BusinessStats, ".fetch", type: :model do
  let(:business) { create(:business, time_zone: "America/Argentina/Buenos_Aires") }
  let(:zone) { Time.find_zone!(business.time_zone) }
  let(:now) { zone.local(2026, 10, 21, 12) }
  let(:owner) { create(:membership, :owner, business: business) }
  let(:service) { create(:service) }
  let(:martin) { create(:professional, user: create(:membership, business: business).user, services: [ service ]) }

  around { |example| with_business(business) { example.run } }
  before do
    travel_to now
    allow(described_class).to receive(:new).and_call_original
  end

  def fetch(membership = owner, key = "this_month")
    described_class.fetch(membership, StatsPeriod.new(key, zone: zone))
  end

  def attended(starts_at, professional: martin)
    create(:appointment, status: :attended, starts_at: starts_at, professional: professional, service: service)
  end

  it "calculates once and then reads the cache, saying when it calculated" do
    attended(zone.local(2026, 10, 5, 10))

    first = fetch
    attended(zone.local(2026, 10, 6, 10))
    second = fetch

    expect(described_class).to have_received(:new).once
    expect(second).to eq(first)
    expect(second[:outcomes]["attended"]).to eq(1)
    expect(second[:calculated_at]).to eq(now)
  end

  it "recalculates the current period after a few minutes" do
    fetch
    attended(zone.local(2026, 10, 5, 10))

    travel described_class::CURRENT_PERIOD_EXPIRES_IN - 1.second
    expect(fetch[:outcomes]["attended"]).to eq(0)
    travel 2.seconds
    expect(fetch[:outcomes]["attended"]).to eq(1)
  end

  it "keeps a closed period for a day" do
    fetch(owner, "last_month")
    attended(zone.local(2026, 9, 28, 10))

    travel 1.hour
    expect(fetch(owner, "last_month")[:outcomes]["attended"]).to eq(0)
    travel 1.day
    expect(fetch(owner, "last_month")[:outcomes]["attended"]).to eq(1)
  end

  it "keeps each period apart" do
    attended(zone.local(2026, 9, 28, 10))

    expect(fetch(owner, "this_month")[:outcomes]["attended"]).to eq(0)
    expect(fetch(owner, "last_month")[:outcomes]["attended"]).to eq(1)
  end

  it "shares an entry among the managers, and keeps each professional's apart" do
    lucia = create(:professional, user: create(:membership, business: business).user, services: [ service ])
    attended(zone.local(2026, 10, 5, 10))
    attended(zone.local(2026, 10, 5, 10), professional: lucia)
    admin = create(:membership, :admin, business: business)

    expect(fetch(owner)[:outcomes]["attended"]).to eq(2)
    expect(fetch(admin)[:outcomes]["attended"]).to eq(2)
    expect(described_class).to have_received(:new).once

    expect(fetch(Membership.find_by!(user: martin.user))[:outcomes]["attended"]).to eq(1)
    expect(fetch(Membership.find_by!(user: lucia.user))[:outcomes]["attended"]).to eq(1)
    expect(described_class).to have_received(:new).exactly(3).times
  end

  it "keeps each business apart" do
    attended(zone.local(2026, 10, 5, 10))
    fetch

    other = create(:business, time_zone: business.time_zone)
    other_owner = create(:membership, :owner, business: other)

    expect(with_business(other) { fetch(other_owner) }[:outcomes]["attended"]).to eq(0)
  end
end
