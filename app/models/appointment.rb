# A customer's appointment with a professional for one service. Pending
# appointments (requests waiting for the business) already hold their time,
# like confirmed ones; the database rejects two active appointments of the
# same professional that overlap, break included.
#
# On create it copies the service's price and break, so later changes to the
# service don't alter it. Its status only changes through the transition
# methods (confirm!, reject!, ...), each recording an event (AppointmentEvent).
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
  # Appointments whose time, break included, overlaps the range.
  scope :overlapping, ->(range) { where(starts_at: ...range.end).where("buffer_ends_at > ?", range.begin) }

  # Before validating (the overlap check needs the end) and again before
  # saving, so they're never missing even when validations are skipped.
  before_validation :derive_from_service
  before_save :derive_from_service

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

  # The business accepts a request. `by` is the user answering it.
  def confirm!(by:)
    transition!(:confirmed, from: :pending, by: by)
  end

  # The business turns a request down, saying why.
  def reject!(by:, reason:)
    transition!(:rejected, from: :pending, by: by, note: reason)
  end

  # The business cancels a confirmed appointment, saying why, until it starts.
  def cancel!(by:, reason:)
    transition!(:cancelled, from: :confirmed, by: by, note: reason, guard: -> { !started? })
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

  private
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
