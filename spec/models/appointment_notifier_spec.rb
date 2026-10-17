require "rails_helper"

RSpec.describe AppointmentNotifier, type: :model do
  include ActiveJob::TestHelper

  let(:business) { create(:business, time_zone: "America/Argentina/Buenos_Aires") }
  let(:zone) { Time.find_zone!(business.time_zone) }
  let(:service) { in_business { create(:service) } }
  let(:professional) do
    in_business do
      create(:professional, services: [ service ]).tap { |created| create(:working_hour, professional: created, day_of_week: 5, start_time: "09:00", end_time: "18:00") }
    end
  end
  let(:appointment) { in_business { create(:appointment, service: service, professional: professional, starts_at: zone.local(2026, 10, 16, 15)) } }
  let(:member) { create(:membership, business: business).user }

  # A Wednesday morning.
  around { |example| travel_to(zone.local(2026, 10, 14, 8)) { example.run } }

  def in_business(&block)
    with_business(business, &block)
  end

  # The customer emails enqueued by the block, as their action names.
  def customer_emails(&block)
    clear_enqueued_jobs
    in_business(&block)
    enqueued_jobs.select { |job| job["arguments"].first == "CustomerAppointmentsMailer" }.map { |job| job["arguments"].second }
  end

  it "emails the customer about the request once it's created (AppointmentRequest records its creation)" do
    appointment

    expect(customer_emails { appointment.events.create!(to_status: "pending", actor_kind: :customer) }).to eq([ "requested" ])
  end

  it "emails the customer about each answer and change" do
    appointment

    expect(customer_emails { appointment.confirm!(by: member) }).to eq([ "confirmed" ])
    expect(customer_emails { appointment.reschedule!(zone.local(2026, 10, 16, 17)) }).to eq([ "rescheduled" ])
    expect(customer_emails { appointment.reassign!(create(:professional, services: [ service ]).tap { |other| create(:working_hour, professional: other, day_of_week: 5, start_time: "09:00", end_time: "18:00") }, by: member) }).to eq([ "reassigned" ])
    expect(customer_emails { appointment.reject!(by: member, reason: "No") }).to eq([ "rejected" ])
  end

  it "emails the customer about cancellations and expirations" do
    other = in_business { create(:appointment, service: service, professional: professional, starts_at: zone.local(2026, 10, 16, 16)) }

    expect(customer_emails { appointment.cancel!(by: :customer) }).to eq([ "cancelled" ])

    travel_to(zone.local(2026, 10, 15, 9))
    expect(customer_emails { other.expire! }).to eq([ "expired" ])
  end

  it "doesn't email about attendance" do
    in_business { appointment.confirm!(by: member) }
    travel_to(appointment.starts_at)

    expect(customer_emails { appointment.mark_attended!(by: member) }).to be_empty
  end

  it "passes the business and the event to the mailer" do
    appointment
    customer_emails { appointment.confirm!(by: member) }

    expect { perform_enqueued_jobs }.to change(ActionMailer::Base.deliveries, :size).by(1)
    expect(ActionMailer::Base.deliveries.last.subject).to include("confirmado")
  end

  it "emails nothing when the change is rolled back" do
    appointment

    emails = customer_emails do
      ActiveRecord::Base.transaction do
        appointment.confirm!(by: member)
        raise ActiveRecord::Rollback
      end
    end

    expect(emails).to be_empty
  end
end
