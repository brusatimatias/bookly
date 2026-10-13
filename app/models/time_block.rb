# A period in which a professional can't be booked (vacation, lunch, an
# errand). Blocks of the same professional don't overlap (also enforced by the
# database). Unlike services and professionals they are deleted, not
# deactivated: they carry no history.
#
# The form can set whole days instead of exact times (all_day, start_date and
# end_date): the block then goes from the first day's midnight to the midnight
# after the last day, in the current (business) time zone. Without an end date
# it blocks a single day.
class TimeBlock < ApplicationRecord
  include BusinessScoped
  include OverlapConstraint

  belongs_to :professional

  attribute :all_day, :boolean, default: false
  attribute :start_date, :date
  attribute :end_date, :date

  # Blocks touching the range; one that ends when the range starts doesn't.
  scope :overlapping, ->(range) { where(starts_at: ...range.end).where("ends_at > ?", range.begin) }
  # Ongoing and future blocks, soonest first.
  scope :upcoming, -> { where("ends_at > ?", Time.current).order(:starts_at) }

  normalizes :reason, with: ->(reason) { reason.squish.presence }

  before_validation :set_range_from_dates, if: :all_day

  validates :start_date, presence: true, if: :all_day
  validates :starts_at, :ends_at, presence: true, unless: :all_day
  validates :reason, length: { maximum: 100 }
  validate :end_date_not_before_start, if: -> { all_day && start_date && end_date }
  validate :ends_after_start, if: -> { !all_day && starts_at && ends_at }
  validate :not_over, if: -> { ends_at && (new_record? || ends_at_changed?) }
  validate :no_overlap, if: -> { professional_id && starts_at && ends_at && errors.none? }

  def range
    starts_at...ends_at
  end

  def ongoing?
    range.cover?(Time.current)
  end

  # From one midnight to another.
  def whole_days?
    starts_at == starts_at.beginning_of_day && ends_at == ends_at.beginning_of_day
  end

  # The last blocked day of a whole days block.
  def last_day
    ends_at.to_date - 1
  end

  # Fills the whole days fields from the stored range, for the edit form: a
  # whole days block opens as such, any other keeps its days in case it is
  # switched to whole days.
  def assign_dates_from_range
    assign_attributes(all_day: whole_days?, start_date: starts_at.to_date, end_date: whole_days? ? last_day : ends_at.to_date)
  end

  private
    def set_range_from_dates
      self.end_date ||= start_date
      self.starts_at = start_date&.in_time_zone
      self.ends_at = end_date && (end_date + 1).in_time_zone
    end

    def end_date_not_before_start
      errors.add(:end_date, :before_start) if end_date < start_date
    end

    def ends_after_start
      errors.add(:ends_at, :after_start) unless ends_at > starts_at
    end

    # A block that already ended changes nothing, and wouldn't even be listed.
    def not_over
      errors.add(:base, :over) if ends_at <= Time.current
    end

    def no_overlap
      errors.add(:base, :overlap) if TimeBlock.where(professional_id: professional_id).where.not(id: id).overlapping(range).exists?
    end
end
