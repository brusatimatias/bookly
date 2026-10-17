# The setup assistant's quick hours: one range (09:00-18:00) on the chosen days
# for every given professional, all in one transaction. Each professional's
# week can be fine tuned later from their schedule.
class SetupHours
  include ActiveModel::Model
  include ActiveModel::Attributes

  TIME_FORMAT = /\A([01]\d|2[0-3]):[0-5]\d\z/

  attribute :days, default: -> { WeeklySchedule::WEEKDAYS }
  attribute :start_time, :string, default: "09:00"
  attribute :end_time, :string, default: "18:00"

  attr_reader :professionals

  validate :days_chosen
  validates :start_time, :end_time, format: { with: TIME_FORMAT }
  validate :end_after_start

  def initialize(attributes = {}, professionals:)
    @professionals = professionals
    super(attributes)
  end

  # Date#wday values, from the checkboxes.
  def days
    Array(super).compact_blank.map(&:to_i).select { |day| day.in?(0..6) }.uniq
  end

  def save
    return false if invalid?

    WorkingHour.transaction do
      professionals.each do |professional|
        days.each { |day| professional.working_hours.create!(day_of_week: day, start_time: start_time, end_time: end_time) }
      end
    end
    true
  end

  private
    def days_chosen
      errors.add(:days, :blank) if days.empty?
    end

    def end_after_start
      return unless start_time.to_s.match?(TIME_FORMAT) && end_time.to_s.match?(TIME_FORMAT)

      errors.add(:end_time, :after_start) unless end_time > start_time
    end
end
