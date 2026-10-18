# One step in an appointment's history: its creation (no from_status) or a
# change of status, with who made it. Never updated nor deleted.
class AppointmentEvent < ApplicationRecord
  include BusinessScoped

  belongs_to :appointment
  # The member who made the change, when the actor is a user.
  belongs_to :actor_user, class_name: "User", optional: true

  enum :actor_kind, { customer: "customer", user: "user", system: "system" }, validate: true

  # Statuses the business can only reach giving a reason.
  REASON_REQUIRED_STATUSES = %w[rejected cancelled].freeze

  normalizes :note, with: ->(note) { note.strip.presence }

  validates :to_status, inclusion: { in: Appointment.statuses.values }
  validates :from_status, inclusion: { in: Appointment.statuses.values }, allow_nil: true
  validates :actor_user, presence: true, if: :user?
  validates :note, length: { maximum: 500 }
  validates :note, presence: true, if: -> { user? && to_status.in?(REASON_REQUIRED_STATUSES) }

  scope :chronological, -> { order(:created_at, :id) }

  after_create_commit -> { AppointmentNotifier.call(self) }

  def readonly?
    persisted?
  end

  # The customer moved the appointment to another time (Appointment#reschedule!);
  # the professional may have changed too.
  def reschedule?
    metadata.key?("from_starts_at")
  end

  # The business moved the appointment to another professional.
  def reassignment?
    metadata.key?("to_professional_id") && !reschedule?
  end

  def from_starts_at
    Time.zone.iso8601(metadata["from_starts_at"]) if reschedule?
  end

  def to_starts_at
    Time.zone.iso8601(metadata["to_starts_at"]) if reschedule?
  end
end
