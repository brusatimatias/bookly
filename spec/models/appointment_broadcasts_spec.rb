require "rails_helper"

RSpec.describe Appointment, "live updates", type: :model do
  let(:business) { create(:business) }

  around { |example| with_business(business) { example.run } }

  def panel_stream(of = business) = turbo_stream_name(Appointment.panel_stream(of))
  def availability_stream(of = business) = turbo_stream_name(Appointment.availability_stream(of))

  it "refreshes the panel and the public week when an appointment is created" do
    expect { create(:appointment) }
      .to have_broadcasted_to(panel_stream).with(a_string_including('action="refresh"'))
      .and have_broadcasted_to(availability_stream).with(a_string_including('action="refresh"'))
  end

  it "refreshes them when an appointment changes, as in a transition" do
    appointment = create(:appointment)

    expect { appointment.confirm!(by: create(:user)) }.to have_broadcasted_to(panel_stream).and have_broadcasted_to(availability_stream)
  end

  it "refreshes the customer's page of that appointment only" do
    appointment = create(:appointment)
    other = create(:appointment, starts_at: appointment.starts_at + 2.hours)

    expect { appointment.confirm!(by: create(:user)) }
      .to have_broadcasted_to(turbo_stream_name(appointment.customer_stream)).with(a_string_including('action="refresh"'))
    expect { appointment.reload.cancel!(by: :customer) }.not_to have_broadcasted_to(turbo_stream_name(other.customer_stream))
  end

  it "doesn't refresh when nothing is saved" do
    appointment = create(:appointment)

    expect { appointment.reject!(by: create(:user), reason: "") rescue nil }.not_to have_broadcasted_to(panel_stream)
  end

  it "only reaches its own business" do
    other = create(:business)

    expect { create(:appointment) }.not_to have_broadcasted_to(panel_stream(other))
    expect(panel_stream(other)).not_to eq(panel_stream)
  end
end
