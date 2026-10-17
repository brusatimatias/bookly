require "rails_helper"

RSpec.describe Appointment, "transitions", type: :model do
  let(:business) { create(:business, time_zone: "America/Argentina/Buenos_Aires", request_expiration_hours: 24) }
  let(:zone) { Time.find_zone!(business.time_zone) }
  let(:service) { create(:service, duration_minutes: 30, buffer_minutes: 0) }
  let(:professional) { professional_working_tuesdays }
  let(:user) { create(:user) }
  # Tuesday 10:00, the day after "now".
  let(:starts_at) { zone.local(2026, 10, 20, 10) }
  let(:appointment) { create(:appointment, service: service, professional: professional, starts_at: starts_at) }

  # Monday noon in the business's time zone.
  around { |example| travel_to(Time.find_zone!("America/Argentina/Buenos_Aires").local(2026, 10, 19, 12)) { with_business(business) { example.run } } }

  def professional_working_tuesdays(**attributes)
    create(:professional, services: [ service ], **attributes).tap do |created|
      create(:working_hour, professional: created, day_of_week: 2, start_time: "09:00", end_time: "13:00")
    end
  end

  def confirmed_appointment
    appointment.tap { |created| created.confirm!(by: user) }
  end

  describe "#confirm!" do
    it "confirms a request and records who did it" do
      expect(appointment.confirm!(by: user)).to eq(appointment)

      expect(appointment.reload).to be_confirmed
      expect(appointment.events.last).to have_attributes(from_status: "pending", to_status: "confirmed", actor_kind: "user", actor_user: user)
    end

    it "fails when the request was already answered, even through another copy" do
      Appointment.find(appointment.id).reject!(by: user, reason: "Closed that day")

      expect { appointment.confirm!(by: user) }.to raise_error(Appointment::InvalidTransition)
      expect(appointment.reload).to be_rejected
      expect(appointment.events.count).to eq(1)
    end

    it "expires a request whose deadline passed instead" do
      appointment
      travel_to(appointment.request_expires_at)

      expect { appointment.confirm!(by: user) }.to raise_error(Appointment::InvalidTransition)
      expect(appointment.reload).to be_expired
      expect(appointment.events.last).to have_attributes(from_status: "pending", to_status: "expired", actor_kind: "system", actor_user: nil)
    end
  end

  describe "#reject!" do
    it "rejects a request with the reason and frees its time" do
      appointment.reject!(by: user, reason: "  We're closed that day  ")

      expect(appointment.reload).to be_rejected
      expect(appointment.events.last).to have_attributes(to_status: "rejected", note: "We're closed that day")
      expect(build(:appointment, service: service, professional: professional, starts_at: starts_at)).to be_valid
    end

    it "requires a reason, changing nothing without one" do
      expect { appointment.reject!(by: user, reason: " ") }.to raise_error(ActiveRecord::RecordInvalid) { |error|
        expect(error.record.errors).to be_of_kind(:note, :blank)
      }
      expect(appointment.reload).to be_pending
      expect(appointment.events.count).to eq(0)
    end

    it "only applies to requests" do
      expect { confirmed_appointment.reject!(by: user, reason: "No") }.to raise_error(Appointment::InvalidTransition)
    end
  end

  describe "#cancel!" do
    it "cancels a confirmed appointment with the reason" do
      confirmed_appointment.cancel!(by: user, reason: "The professional is ill")

      expect(appointment.reload).to be_cancelled
      expect(appointment.events.last).to have_attributes(from_status: "confirmed", to_status: "cancelled", note: "The professional is ill")
    end

    it "requires a reason" do
      expect { confirmed_appointment.cancel!(by: user, reason: nil) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(appointment.reload).to be_confirmed
    end

    it "is not possible once the appointment started" do
      confirmed_appointment
      travel_to(starts_at)

      expect { appointment.cancel!(by: user, reason: "Too late") }.to raise_error(Appointment::InvalidTransition)
    end

    it "doesn't apply to requests, which are rejected" do
      expect { appointment.cancel!(by: user, reason: "No") }.to raise_error(Appointment::InvalidTransition)
    end

    describe "by the customer" do
      # Tuesday 10:00 minus 12 hours: until Monday 22:00.
      before { business.update!(cancellation_window_hours: 12) }

      it "withdraws a request, with an optional reason" do
        appointment.cancel!(by: :customer)

        expect(appointment.reload).to be_cancelled
        expect(appointment.events.last).to have_attributes(from_status: "pending", to_status: "cancelled", actor_kind: "customer", note: nil)
      end

      it "cancels a confirmed appointment until the cancellation window closes" do
        confirmed_appointment
        travel_to(zone.local(2026, 10, 19, 22))

        appointment.cancel!(by: :customer, reason: "  Can't make it ")

        expect(appointment.reload).to be_cancelled
        expect(appointment.events.last).to have_attributes(from_status: "confirmed", actor_kind: "customer", note: "Can't make it")
      end

      it "is not possible once the window closed" do
        confirmed_appointment
        travel_to(zone.local(2026, 10, 19, 22, 1))

        expect { appointment.cancel!(by: :customer) }.to raise_error(Appointment::InvalidTransition)
        expect(appointment.reload).to be_confirmed
      end

      it "expires an overdue request instead" do
        appointment
        travel_to(appointment.request_expires_at)

        expect { appointment.cancel!(by: :customer) }.to raise_error(Appointment::InvalidTransition)
        expect(appointment.reload).to be_expired
      end
    end
  end

  describe "#reschedule!" do
    let(:new_starts_at) { starts_at + 2.hours }

    before { business.update!(cancellation_window_hours: 12) }

    it "moves a confirmed appointment back to pending at the new time, freeing the old one" do
      confirmed_appointment.reschedule!(new_starts_at)

      expect(appointment.reload).to have_attributes(status: "pending", starts_at: new_starts_at, ends_at: new_starts_at + 30.minutes,
                                                    professional: professional, request_expires_at: Time.current + 24.hours)
      expect(appointment.events.last).to have_attributes(
        from_status: "confirmed", to_status: "pending", actor_kind: "customer",
        metadata: { "from_starts_at" => starts_at.utc.iso8601, "to_starts_at" => new_starts_at.utc.iso8601 }
      )
      expect(build(:appointment, service: service, professional: professional, starts_at: starts_at)).to be_valid
    end

    it "is remembered while the business answers" do
      expect(confirmed_appointment.rescheduled_from).to be_nil

      appointment.reschedule!(new_starts_at)
      expect(appointment.reload.rescheduled_from).to eq(starts_at)

      appointment.confirm!(by: user)
      expect(appointment.reload.rescheduled_from).to be_nil
    end

    it "never gives the business until after the new time" do
      business.update!(request_expiration_hours: 72)

      confirmed_appointment.reschedule!(new_starts_at)

      expect(appointment.reload.request_expires_at).to eq(new_starts_at)
    end

    it "can move to a time overlapping its own" do
      confirmed_appointment.reschedule!(starts_at + 15.minutes)

      expect(appointment.reload.starts_at).to eq(starts_at + 15.minutes)
    end

    it "changes the professional when given another one" do
      other = professional_working_tuesdays(name: "Other")

      confirmed_appointment.reschedule!(new_starts_at, other)

      expect(appointment.reload.professional).to eq(other)
      expect(appointment.events.last.metadata).to include("from_professional_id" => professional.id, "to_professional_id" => other.id)
    end

    it "rejects a time someone else holds, changing nothing" do
      confirmed_appointment
      create(:appointment, service: service, professional: professional, starts_at: new_starts_at)

      expect { appointment.reschedule!(new_starts_at) }.to raise_error(ActiveRecord::RecordInvalid) { |error|
        expect(error.record.errors).to be_of_kind(:base, :overlap)
      }
      expect(appointment.reload).to have_attributes(status: "confirmed", starts_at: starts_at)
      expect(appointment.events.count).to eq(1)
    end

    it "only applies to confirmed appointments, to another time, until the window closes" do
      expect { appointment.reschedule!(new_starts_at) }.to raise_error(Appointment::InvalidTransition)
      expect { confirmed_appointment.reschedule!(starts_at) }.to raise_error(Appointment::InvalidTransition)

      travel_to(zone.local(2026, 10, 19, 22, 1))
      expect { appointment.reschedule!(new_starts_at) }.to raise_error(Appointment::InvalidTransition)
      expect(appointment.reload).to have_attributes(status: "confirmed", starts_at: starts_at)
    end
  end

  describe "what the customer can do" do
    before { business.update!(cancellation_window_hours: 12) }

    it "is withdrawing a request while it waits" do
      expect(appointment).to have_attributes(customer_can_cancel?: true, customer_can_reschedule?: false)

      travel_to(appointment.request_expires_at)
      expect(appointment.customer_can_cancel?).to be(false)
    end

    it "is cancelling or rescheduling a confirmed appointment until the window closes" do
      expect(confirmed_appointment).to have_attributes(customer_deadline: zone.local(2026, 10, 19, 22),
                                                       customer_can_cancel?: true, customer_can_reschedule?: true)

      travel_to(zone.local(2026, 10, 19, 22, 1))
      expect(appointment).to have_attributes(customer_can_cancel?: false, customer_can_reschedule?: false)
    end

    it "is nothing once it's over" do
      appointment.reject!(by: user, reason: "No")

      expect(appointment).to have_attributes(customer_can_cancel?: false, customer_can_reschedule?: false)
    end
  end

  describe "attendance" do
    it "marks a confirmed appointment as attended or no show once it started" do
      no_show = create(:appointment, service: service, professional: professional, starts_at: starts_at + 1.hour).tap { |created| created.confirm!(by: user) }
      confirmed_appointment
      travel_to(starts_at + 1.hour)

      appointment.mark_attended!(by: user)
      no_show.mark_no_show!(by: user)

      expect(appointment.reload).to be_attended
      expect(no_show.reload).to be_no_show
      expect(no_show.events.last).to have_attributes(from_status: "confirmed", to_status: "no_show", actor_user: user)
    end

    it "is not possible before the start" do
      expect { confirmed_appointment.mark_attended!(by: user) }.to raise_error(Appointment::InvalidTransition)
      expect { appointment.mark_no_show!(by: user) }.to raise_error(Appointment::InvalidTransition)
    end

    it "only applies to confirmed appointments" do
      appointment
      travel_to(starts_at + 1.minute)

      expect { appointment.mark_attended!(by: user) }.to raise_error(Appointment::InvalidTransition)
    end
  end

  describe "#reassign!" do
    let(:other) { professional_working_tuesdays(name: "Other") }

    it "moves the appointment to a free professional, keeping its status" do
      confirmed_appointment.reassign!(other, by: user)

      expect(appointment.reload).to have_attributes(professional: other, status: "confirmed")
      expect(appointment.events.last).to have_attributes(
        from_status: "confirmed", to_status: "confirmed", actor_user: user,
        metadata: { "from_professional_id" => professional.id, "to_professional_id" => other.id }
      )
    end

    it "ignores the customers' booking window" do
      business.update!(min_booking_notice_hours: 72)

      expect { appointment.reassign!(other, by: user) }.not_to raise_error
    end

    it "requires a professional offering the service" do
      other.update!(services: [ create(:service) ])

      expect { appointment.reassign!(other, by: user) }.to raise_error(ActiveRecord::RecordInvalid) { |error|
        expect(error.record.errors).to be_of_kind(:service, :not_offered)
      }
      expect(appointment.reload.professional).to eq(professional)
      expect(appointment.events.count).to eq(0)
    end

    it "requires an active professional" do
      other.deactivate!

      expect { appointment.reassign!(other, by: user) }.to raise_error(ActiveRecord::RecordInvalid) { |error|
        expect(error.record.errors).to be_of_kind(:professional, :inactive)
      }
    end

    it "requires the professional to work the whole service" do
      other.working_hours.update_all(end_time: "10:15")

      expect { appointment.reassign!(other, by: user) }.to raise_error(ActiveRecord::RecordInvalid) { |error|
        expect(error.record.errors).to be_of_kind(:professional, :not_working)
      }
    end

    it "rejects a professional with a block at that time" do
      create(:time_block, professional: other, starts_at: starts_at + 15.minutes, ends_at: starts_at + 1.hour)

      expect { appointment.reassign!(other, by: user) }.to raise_error(ActiveRecord::RecordInvalid) { |error|
        expect(error.record.errors).to be_of_kind(:professional, :blocked)
      }
    end

    it "rejects a professional with another appointment then" do
      create(:appointment, service: service, professional: other, starts_at: starts_at + 15.minutes)

      expect { appointment.reassign!(other, by: user) }.to raise_error(ActiveRecord::RecordInvalid) { |error|
        expect(error.record.errors).to be_of_kind(:base, :overlap)
      }
    end

    it "only applies to active appointments that haven't started, and to another professional" do
      expect { appointment.reassign!(professional, by: user) }.to raise_error(Appointment::InvalidTransition)

      travel_to(starts_at)
      expect { confirmed_appointment.reassign!(other, by: user) }.to raise_error(Appointment::InvalidTransition)
    end

    it "doesn't apply to finished appointments" do
      appointment.reject!(by: user, reason: "No")

      expect { appointment.reassign!(other, by: user) }.to raise_error(Appointment::InvalidTransition)
    end
  end

  describe "#expire!" do
    it "expires a request whose deadline passed, as the system" do
      appointment
      travel_to(appointment.request_expires_at + 1.minute)

      appointment.expire!

      expect(appointment.reload).to be_expired
      expect(appointment.events.last).to have_attributes(to_status: "expired", actor_kind: "system")
    end

    it "fails before the deadline or once answered" do
      expect { appointment.expire! }.to raise_error(Appointment::InvalidTransition)

      confirmed_appointment
      travel_to(appointment.request_expires_at + 1.minute)
      expect { appointment.expire! }.to raise_error(Appointment::InvalidTransition)
    end
  end
end
