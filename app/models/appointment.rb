# A customer's appointment with a professional for one service. Pending
# appointments (requests waiting for the business) already hold their time,
# like confirmed ones; the database rejects two active appointments of the
# same professional that overlap, break included.
#
# On create it copies the service's price and break, so later changes to the
# service don't alter it. State transitions come with request management.
class Appointment < ApplicationRecord
  include BusinessScoped
  include OverlapConstraint

  # Pending and confirmed: the ones that hold their time.
  ACTIVE_STATUSES = %w[pending confirmed].freeze

  belongs_to :service
  belongs_to :professional
  belongs_to :customer

  enum :status, { pending: "pending", confirmed: "confirmed", rejected: "rejected", expired: "expired",
                  cancelled: "cancelled", attended: "attended", no_show: "no_show" }, validate: true

  scope :active, -> { where(status: ACTIVE_STATUSES) }
  # Appointments whose time, break included, overlaps the range.
  scope :overlapping, ->(range) { where(starts_at: ...range.end).where("buffer_ends_at > ?", range.begin) }

  # Before validating (the overlap check needs the end) and again before
  # saving, so they're never missing even when validations are skipped.
  before_validation :derive_from_service
  before_save :derive_from_service

  validates :starts_at, presence: true
  validates :customer_notes, length: { maximum: 500 }
  validate :service_offered_by_professional, if: -> { service && professional && (new_record? || service_id_changed? || professional_id_changed?) }
  validate :no_overlap, if: -> { active? && professional_id && starts_at && buffer_ends_at && errors.none? }

  def active?
    status.in?(ACTIVE_STATUSES)
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

    def service_offered_by_professional
      errors.add(:service, :not_offered) unless professional.service_ids.include?(service_id)
    end

    def no_overlap
      errors.add(:base, :overlap) if Appointment.active.where(professional_id: professional_id).where.not(id: id).overlapping(busy_range).exists?
    end
end
