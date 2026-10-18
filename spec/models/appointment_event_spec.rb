require "rails_helper"

RSpec.describe AppointmentEvent, type: :model do
  let(:business) { create(:business) }

  around { |example| with_business(business) { example.run } }

  it "is valid with the factory defaults" do
    expect(build(:appointment_event)).to be_valid
  end

  it "requires a known status to move to" do
    event = build(:appointment_event, to_status: "lost")

    expect(event).not_to be_valid
    expect(event.errors).to be_added(:to_status, :inclusion, value: "lost")
  end

  it "allows no previous status, for the creation" do
    expect(build(:appointment_event, from_status: nil)).to be_valid
    expect(build(:appointment_event, from_status: "lost")).not_to be_valid
  end

  it "requires the user when a member made the change" do
    expect(build(:appointment_event, actor_kind: :user)).not_to be_valid
    expect(build(:appointment_event, actor_kind: :user, actor_user: create(:user))).to be_valid
  end

  it "requires a reason when the team rejects or cancels" do
    user = create(:user)

    expect(build(:appointment_event, to_status: "rejected", actor_kind: :user, actor_user: user, note: "  ")).not_to be_valid
    expect(build(:appointment_event, to_status: "cancelled", actor_kind: :user, actor_user: user)).not_to be_valid
    expect(build(:appointment_event, to_status: "cancelled", actor_kind: :user, actor_user: user, note: "Ill")).to be_valid
    expect(build(:appointment_event, to_status: "cancelled", actor_kind: :customer)).to be_valid
    expect(build(:appointment_event, to_status: "confirmed", actor_kind: :user, actor_user: user)).to be_valid
  end

  it "tells a customer's reschedule from a business's reassignment" do
    appointment = create(:appointment)
    reschedule = build(:appointment_event, :reschedule, appointment: appointment, from: appointment.starts_at - 2.hours)
    reassignment = build(:appointment_event, metadata: { "from_professional_id" => 1, "to_professional_id" => 2 })

    expect(reschedule).to have_attributes(reschedule?: true, reassignment?: false, from_starts_at: appointment.starts_at - 2.hours,
                                          to_starts_at: appointment.starts_at)
    expect(reassignment).to have_attributes(reschedule?: false, reassignment?: true, from_starts_at: nil)
    reschedule.metadata.merge!("from_professional_id" => 1, "to_professional_id" => 2)
    expect(reschedule.reassignment?).to be(false)
  end

  it "can't be changed once recorded" do
    event = create(:appointment_event)

    expect { event.update!(note: "Changed") }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "lists an appointment's events in order" do
    appointment = create(:appointment)
    created = create(:appointment_event, appointment: appointment, created_at: 1.hour.ago)
    confirmed = create(:appointment_event, appointment: appointment, from_status: "pending", to_status: "confirmed",
                                           actor_kind: :system)

    expect(appointment.events).to eq([ created, confirmed ])
  end

  describe "database constraints" do
    let!(:event) { create(:appointment_event) }

    # Straight to the database (recorded events are read only in Rails), in a
    # savepoint so one failure doesn't abort the example's transaction.
    def update_columns!(**values)
      described_class.transaction(requires_new: true) { described_class.where(id: event.id).update_all(values) }
    end

    def update_column!(column, value)
      update_columns!(column => value)
    end

    it "rejects unknown statuses and actors" do
      expect { update_column!(:to_status, "lost") }.to raise_error(ActiveRecord::StatementInvalid, /to_status_valid/)
      expect { update_column!(:from_status, "lost") }.to raise_error(ActiveRecord::StatementInvalid, /from_status_valid/)
      expect { update_column!(:actor_kind, "robot") }.to raise_error(ActiveRecord::StatementInvalid, /actor_kind_valid/)
    end

    it "requires the user for a member's change" do
      expect { update_column!(:actor_kind, "user") }.to raise_error(ActiveRecord::StatementInvalid, /user_actor_present/)
    end

    it "requires a reason for the team's rejections and cancellations" do
      team_rejection = { actor_kind: "user", actor_user_id: create(:user).id, to_status: "rejected" }

      expect { update_columns!(**team_rejection, note: nil) }.to raise_error(ActiveRecord::StatementInvalid, /team_reason_present/)
      expect { update_columns!(**team_rejection, note: " ") }.to raise_error(ActiveRecord::StatementInvalid, /team_reason_present/)
      expect { update_columns!(**team_rejection, note: "Closed that day") }.not_to raise_error
    end

    it "rejects an appointment from another business" do
      other = create(:business)
      foreign = with_business(other) { create(:appointment) }

      expect { update_column!(:appointment_id, foreign.id) }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end
end
