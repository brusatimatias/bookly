require "rails_helper"

RSpec.describe ExpireRequestsJob, type: :job do
  let(:business) { create(:business, request_expiration_hours: 2) }
  let(:other_business) { create(:business, request_expiration_hours: 2) }

  def request_in(business, **attributes)
    with_business(business) { create(:appointment, **attributes) }
  end

  it "expires the overdue requests of every business, each within its own" do
    overdue = request_in(business)
    other_overdue = request_in(other_business)

    travel_to(3.hours.from_now) { described_class.perform_now }

    with_business(business) do
      expect(overdue.reload).to be_expired
      expect(overdue.events.last).to have_attributes(to_status: "expired", actor_kind: "system", business_id: business.id)
    end
    with_business(other_business) do
      expect(other_overdue.reload).to be_expired
      expect(other_overdue.events.last.business_id).to eq(other_business.id)
    end
  end

  it "leaves requests still on time and answered ones" do
    on_time = request_in(business, starts_at: 2.days.from_now)
    confirmed = request_in(business, status: :confirmed, starts_at: 2.days.from_now + 1.hour)
    travel_to(1.hour.from_now) { described_class.perform_now }

    with_business(business) do
      expect(on_time.reload).to be_pending
      expect(confirmed.reload).to be_confirmed
      expect(AppointmentEvent.count).to eq(0)
    end
  end

  it "expires right at the deadline" do
    request = request_in(business)

    travel_to(request.request_expires_at.ceil) { described_class.perform_now }

    with_business(business) { expect(request.reload).to be_expired }
  end

  it "leaves no current business behind" do
    request_in(business)

    travel_to(3.hours.from_now) { described_class.perform_now }

    expect(Current.business).to be_nil
  end

  it "runs every minute" do
    schedule = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true)

    expect(schedule.dig("production", "expire_requests")).to include("class" => "ExpireRequestsJob", "schedule" => "every minute")
  end
end
