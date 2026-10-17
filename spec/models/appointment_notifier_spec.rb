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

  # The emails enqueued by the block, as [mailer, action] pairs.
  def emails(&block)
    clear_enqueued_jobs
    in_business(&block)
    enqueued_jobs.select { |job| job["job_class"] == "ActionMailer::MailDeliveryJob" }.map { |job| job["arguments"].first(2) }
  end

  def customer_emails(&block)
    emails(&block).filter_map { |mailer, action| action if mailer == "CustomerAppointmentsMailer" }
  end

  # { action => [recipient emails] } for the team emails enqueued by the block.
  def team_emails(&block)
    clear_enqueued_jobs
    in_business(&block)
    enqueued_jobs.select { |job| job["arguments"].first == "TeamAppointmentsMailer" }
      .group_by { |job| job["arguments"].second }
      .transform_values { |jobs| jobs.map { |job| ActiveJob::Arguments.deserialize(job["arguments"]).last.dig(:params, :recipient).email_address } }
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

  describe "the team" do
    let!(:owner) { create(:membership, :owner, business: business, user: create(:user, email_address: "owner@example.com")).user }

    before { create(:membership, :admin, business: business, user: create(:user, email_address: "admin@example.com")) }

    it "hears about new requests, changes of time and cancellations from the customer, each member once" do
      appointment

      expect(team_emails { appointment.events.create!(to_status: "pending", actor_kind: :customer) })
        .to eq("new_request" => %w[owner@example.com admin@example.com])

      in_business { appointment.confirm!(by: owner) }
      expect(team_emails { appointment.reschedule!(zone.local(2026, 10, 16, 17)) }).to eq("customer_rescheduled" => %w[owner@example.com admin@example.com])
      expect(team_emails { appointment.cancel!(by: :customer) }).to eq("customer_cancelled" => %w[owner@example.com admin@example.com])
    end

    it "includes the appointment's professional when they have an account" do
      user = create(:membership, business: business, user: create(:user, email_address: "pro@example.com")).user
      in_business { professional.update!(user: user) }

      expect(team_emails { appointment.cancel!(by: :customer) }.fetch("customer_cancelled")).to eq(%w[pro@example.com owner@example.com admin@example.com])
    end

    it "emails the owner once when they are also the professional" do
      in_business { professional.update!(user: owner) }

      expect(team_emails { appointment.cancel!(by: :customer) }.fetch("customer_cancelled")).to eq(%w[owner@example.com admin@example.com])
    end

    it "hears nothing about what the team itself does" do
      appointment

      expect(team_emails { appointment.confirm!(by: owner) }).to be_empty
      expect(team_emails { appointment.cancel!(by: owner, reason: "Cerramos") }).to be_empty
    end
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
