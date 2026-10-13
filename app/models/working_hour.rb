# A weekly range in which a professional works, in the business's local time
# (Monday 09:00-13:00). A day can have several ranges; they don't cross
# midnight or overlap (also enforced by the database).
class WorkingHour < ApplicationRecord
  include BusinessScoped
  include OverlapConstraint

  # Wall clock times, not instants: Rails would otherwise shift them to and
  # from the current time zone (14:00 read as 11:00 in Buenos Aires).
  self.skip_time_zone_conversion_for_attributes = %i[start_time end_time]

  belongs_to :professional

  scope :ordered, -> { order(:day_of_week, :start_time) }

  validates :day_of_week, inclusion: { in: 0..6 }
  validates :start_time, :end_time, presence: true
  validate :end_after_start, if: -> { start_time && end_time }
  validate :no_overlap, if: -> { professional_id && day_of_week && errors.none? }

  # Whether the range overlaps another one of the same day. Ranges that only
  # touch (09:00-13:00 and 13:00-17:00) don't.
  def overlaps?(other)
    day_of_week == other.day_of_week && start_time < other.end_time && other.start_time < end_time
  end

  private
    def end_after_start
      errors.add(:end_time, :after_start) unless end_time > start_time
    end

    def no_overlap
      siblings = WorkingHour.where(professional_id: professional_id, day_of_week: day_of_week).where.not(id: id)
      errors.add(:base, :overlap) if siblings.any? { |other| overlaps?(other) }
    end
end
