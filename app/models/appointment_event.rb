# One step in an appointment's history: its creation (no from_status) or a
# change of status, with who made it. Never updated nor deleted.
class AppointmentEvent < ApplicationRecord
  include BusinessScoped

  belongs_to :appointment
  # The member who made the change, when the actor is a user.
  belongs_to :actor_user, class_name: "User", optional: true

  enum :actor_kind, { customer: "customer", user: "user", system: "system" }, validate: true

  validates :to_status, inclusion: { in: Appointment.statuses.values }
  validates :from_status, inclusion: { in: Appointment.statuses.values }, allow_nil: true
  validates :actor_user, presence: true, if: :user?
  validates :note, length: { maximum: 500 }

  scope :chronological, -> { order(:created_at, :id) }

  def readonly?
    persisted?
  end
end
