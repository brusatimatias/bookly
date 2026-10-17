# A customer's appointment with a professional for one service. Pending
# appointments (requests waiting for the business) already hold their time,
# like confirmed ones; the database rejects two active appointments of the
# same professional that overlap, break included.
#
# On create it copies the service's price and break, so later changes to the
# service don't alter it. Its status and time only change through the
# transition methods (confirm!, reject!, reschedule!, ...), each recording an
# event (AppointmentEvent).
class Appointment < ApplicationRecord
  include BusinessScoped
  include OverlapConstraint

  # Raised when a change doesn't apply to the appointment as it is now: already
  # answered, already started, or a request whose deadline passed.
  class InvalidTransition < StandardError; end

  # Pending and confirmed: the ones that hold their time.
  ACTIVE_STATUSES = %w[pending confirmed].freeze

  belongs_to :service
  belongs_to :professional
  belongs_to :customer
  has_many :events, -> { chronological }, class_name: "AppointmentEvent", dependent: :restrict_with_exception

  enum :status, { pending: "pending", confirmed: "confirmed", rejected: "rejected", expired: "expired",
                  cancelled: "cancelled", attended: "attended", no_show: "no_show" }, validate: true

  # The customer's personal link (request page, and later cancel and
  # reschedule). It embeds nothing else, so it stays valid for the
  # appointment's whole life, even when it moves to another time.
  generates_token_for :management

  scope :active, -> { where(status: ACTIVE_STATUSES) }
  # Requests still waiting for an answer (an overdue one is about to expire).
  scope :awaiting_answer, -> { pending.where("request_expires_at > ?", Time.current) }
  # What the agenda shows: requests, confirmed appointments and their attendance.
  scope :on_agenda, -> { where(status: %w[pending confirmed attended no_show]) }
  # Confirmed appointments that haven't started and whose reminder is due (the
  # business's reminder_hours_before before them; 0 turns them off) but not
  # sent, in active businesses. One confirmed after its reminder was due gets
  # none: the confirmation just told the customer. Run it across businesses.
  scope :due_for_reminder, -> {
    reminder_due_at = "appointments.starts_at - businesses.reminder_hours_before * interval '1 hour'"
    confirmed.where(reminder_sent_at: nil, starts_at: Time.current..).joins(:business)
      .where(businesses: { status: "active" }).where("businesses.reminder_hours_before > 0")
      .where("#{reminder_due_at} <= ?", Time.current)
      .where("NOT EXISTS (SELECT 1 FROM appointment_events WHERE appointment_events.appointment_id = appointments.id " \
             "AND appointment_events.to_status = 'confirmed' AND appointment_events.created_at > #{reminder_due_at})")
  }
  # Appointments whose time, break included, overlaps the range.
  scope :overlapping, ->(range) { where(starts_at: ...range.end).where("buffer_ends_at > ?", range.begin) }

  # Before validating (the overlap check needs the end) and again before
  # saving, so they're never missing even when validations are skipped.
  before_validation :derive_from_service
  before_save :derive_from_service
  after_commit :broadcast_refresh

  validates :starts_at, presence: true
  validates :customer_notes, length: { maximum: 500 }
  validate :service_offered_by_professional, if: -> { service && professional && (new_record? || service_id_changed? || professional_id_changed?) }
  validate :professional_free, on: :update, if: -> { professional_id_changed? && professional && starts_at && ends_at && errors.none? }
  validate :no_overlap, if: -> { active? && professional_id && starts_at && buffer_ends_at && errors.none? }

  def active?
    status.in?(ACTIVE_STATUSES)
  end

  def started?
    starts_at <= Time.current
  end

  # A request nobody answered in time.
  def request_overdue?
    pending? && request_expires_at <= Time.current
  end

  # For a request that comes from a reschedule: the time it had before. Reads
  # the events (preload them for lists).
  def rescheduled_from
    events.reverse.find { |event| event.to_status == "pending" }&.from_starts_at if pending?
  end

  # Until when the customer may cancel or reschedule a confirmed appointment
  # on their own (the business's cancellation window); later, they contact
  # the business.
  def customer_deadline
    starts_at - Current.business!.cancellation_window_hours.hours
  end

  # A request can be withdrawn while it waits for an answer.
  def customer_can_cancel?
    (pending? && !request_overdue?) || customer_can_reschedule?
  end

  def customer_can_reschedule?
    confirmed? && Time.current <= customer_deadline
  end

  # Who on the team hears about what the customer does: the professional (when
  # they have an account), the owner and the admins, each once.
  def team_recipients
    managers = User.where(id: Current.business!.memberships.where(role: %w[owner admin]).select(:user_id)).order(:id)
    [ professional.user, *managers ].compact.uniq
  end

  # The business accepts a request. `by` is the user answering it.
  def confirm!(by:)
    transition!(:confirmed, from: :pending, by: by)
  end

  # The business turns a request down, saying why.
  def reject!(by:, reason:)
    transition!(:rejected, from: :pending, by: by, note: reason)
  end

  # The business cancels a confirmed appointment, saying why, until it starts.
  # The customer withdraws a request, or cancels a confirmed appointment
  # until the cancellation window closes; their reason is optional.
  def cancel!(by:, reason: nil)
    if by == :customer
      transition!(:cancelled, from: ACTIVE_STATUSES, by: by, note: reason, guard: -> { customer_can_cancel? })
    else
      transition!(:cancelled, from: :confirmed, by: by, note: reason, guard: -> { !started? })
    end
  end

  # The customer moves a confirmed appointment to another time, until the
  # cancellation window closes; the caller checks the time is free
  # (AppointmentReschedule). The old time is freed at once, and the
  # appointment goes back to pending with a new deadline for the business: if
  # it rejects the new time or doesn't answer, the appointment is lost. The
  # professional may change when the customer had asked for any.
  def reschedule!(new_starts_at, new_professional = professional)
    transition!(:pending, from: :confirmed, by: :customer, guard: -> { customer_can_reschedule? && new_starts_at != starts_at }) do
      metadata = { from_starts_at: starts_at.utc.iso8601, to_starts_at: new_starts_at.utc.iso8601 }
      if new_professional.id != professional_id
        metadata.merge!(from_professional_id: professional_id, to_professional_id: new_professional.id)
        self.professional = new_professional
      end
      self.starts_at = new_starts_at
      # The new time, once confirmed, gets its own reminder.
      self.reminder_sent_at = nil
      self.request_expires_at = [ Current.business!.request_expiration_hours.hours.from_now, new_starts_at ].min
      metadata
    end
  end

  # Attendance, once the appointment started.
  def mark_attended!(by:)
    transition!(:attended, from: :confirmed, by: by, guard: -> { started? })
  end

  def mark_no_show!(by:)
    transition!(:no_show, from: :confirmed, by: by, guard: -> { started? })
  end

  # Moves an active appointment that hasn't started to another professional,
  # who must offer the service and be free then (working hours, no block, no
  # other appointment; the customer's booking window doesn't apply). The
  # status stays the same.
  def reassign!(new_professional, by:)
    transition!(from: ACTIVE_STATUSES, by: by, guard: -> { !started? && new_professional.id != professional_id }) do
      metadata = { from_professional_id: professional_id, to_professional_id: new_professional.id }
      self.professional = new_professional
      metadata
    end
  end

  # A request nobody answered in time (ExpireRequestsJob).
  def expire!
    transition!(:expired, from: :pending, by: :system, guard: -> { request_overdue? })
  end

  # The time the professional is busy: the service plus the break after it.
  def busy_range
    starts_at...buffer_ends_at
  end

  # Streams of the pages that show appointments: the panel's (agenda, requests,
  # dashboard, appointment page) and the public week of free times. Each one
  # refreshes itself when an appointment is created or changes.
  def self.panel_stream(business) = [ business, :appointments ]
  def self.availability_stream(business) = [ business, :availability ]
  # The customer's page of this appointment, which refreshes itself when the
  # business answers or changes it.
  def customer_stream = [ self, :customer ]

  private
    def broadcast_refresh
      Turbo::StreamsChannel.broadcast_refresh_to(*Appointment.panel_stream(business))
      Turbo::StreamsChannel.broadcast_refresh_to(*Appointment.availability_stream(business))
      Turbo::StreamsChannel.broadcast_refresh_to(*customer_stream)
    end

    # Price and break are copied once; the end follows the start. A request
    # can't expire after the appointment it asks for.
    def derive_from_service
      return unless service && starts_at

      if new_record?
        self.price_cents ||= service.price_cents
        self.buffer_minutes ||= service.effective_buffer_minutes
        self.request_expires_at ||= [ business.request_expiration_hours.hours.from_now, starts_at ].min if pending?
      end

      if new_record? || starts_at_changed?
        self.ends_at = starts_at + service.duration_minutes.minutes
        self.buffer_ends_at = ends_at + buffer_minutes.minutes
      end
    end

    # Locks the row and, if it is still in one of the `from` statuses and the
    # guard passes, moves it to `to` (or keeps its status, when nil) and records
    # the event; the block may change other attributes and returns the event's
    # metadata. `by` is a User, :customer or :system. Raises InvalidTransition
    # otherwise, and RecordInvalid when the appointment or the event (a missing
    # reason) is invalid, changing nothing.
    #
    # A request whose deadline passed expires instead, and raises.
    def transition!(to = nil, from:, by:, note: nil, guard: -> { true }, &changes)
      expired_instead = with_lock do
        if request_overdue? && to != :expired
          record_transition!(:expired, by: :system)
          true
        else
          raise InvalidTransition unless status.in?(Array(from).map(&:to_s)) && guard.call

          record_transition!(to, by: by, note: note, &changes)
          false
        end
      end
      raise InvalidTransition if expired_instead

      self
    end

    def record_transition!(to, by:, note: nil)
      from_status = status
      metadata = block_given? ? yield : {}
      event = AppointmentEvent.new(appointment: self, from_status: from_status, to_status: (to || status).to_s, note: note, metadata: metadata,
        **(by.is_a?(User) ? { actor_kind: :user, actor_user: by } : { actor_kind: by }))
      # Checked first, so a missing reason leaves the appointment untouched.
      event.validate!

      self.status = to if to
      save!
      event.save!
    end

    def service_offered_by_professional
      errors.add(:service, :not_offered) unless professional.service_ids.include?(service_id)
    end

    # For reassignments: the new professional must be active, work the whole
    # service and have no block over it.
    def professional_free
      if !professional.active?
        errors.add(:professional, :inactive)
      elsif !within_working_hours?
        errors.add(:professional, :not_working)
      elsif TimeBlock.where(professional_id: professional_id).overlapping(starts_at...ends_at).exists?
        errors.add(:professional, :blocked)
      end
    end

    def within_working_hours?
      zone = Time.find_zone!(Current.business!.time_zone)
      local_start = starts_at.in_time_zone(zone)
      local_end = ends_at.in_time_zone(zone)
      return false unless local_start.to_date == local_end.to_date

      professional.working_hours.where(day_of_week: local_start.wday).any? do |range|
        range.start_time.seconds_since_midnight <= local_start.seconds_since_midnight &&
          range.end_time.seconds_since_midnight >= local_end.seconds_since_midnight
      end
    end

    def no_overlap
      errors.add(:base, :overlap) if Appointment.active.where(professional_id: professional_id).where.not(id: id).overlapping(busy_range).exists?
    end
end
