# Form object for a professional's weekly hours: the whole week is edited at
# once, and saving replaces every range in a single transaction.
class WeeklySchedule
  include ActiveModel::Model

  # Date#wday values, Monday first, as the week is shown.
  DAYS = [ 1, 2, 3, 4, 5, 6, 0 ].freeze
  WEEKDAYS = [ 1, 2, 3, 4, 5 ].freeze

  attr_reader :professional, :ranges

  def initialize(professional)
    @professional = professional
    @ranges = professional.working_hours.ordered.to_a
  end

  def ranges_on(day)
    ranges.select { |range| range.day_of_week == day }
  end

  # Replaces the week with the given ranges ({ day_of_week:, start_time:,
  # end_time: } hashes); rows without times are skipped. If any range is
  # invalid nothing changes, each range keeps its errors and it returns false.
  def update(attributes)
    @ranges = attributes.reject { |range| range[:start_time].blank? && range[:end_time].blank? }
      .map { |range| WorkingHour.new(range.slice(:day_of_week, :start_time, :end_time).merge(professional: professional)) }
      .sort_by { |range| [ range.day_of_week.to_i, range.start_time.to_s ] }

    WorkingHour.transaction do
      WorkingHour.where(professional: professional).delete_all
      # One by one, so each range is checked against the ones saved before it.
      ranges.each(&:save)
      raise ActiveRecord::Rollback if invalid_ranges?
    end

    errors.add(:base, :invalid_ranges) if invalid_ranges?
    errors.none?
  end

  private
    def invalid_ranges?
      ranges.any? { |range| range.errors.any? }
    end
end
