# A period of the statistics page, in the business's time zone: this month,
# last month or the last 90 days (today included). Whole days, so this month
# also covers what's still to come.
class StatsPeriod
  KEYS = %w[this_month last_month last_90_days].freeze
  DEFAULT = "this_month"

  attr_reader :key, :days, :range

  # An unknown key falls back to the default.
  def initialize(key, zone: Time.zone, now: Time.current)
    @key = KEYS.include?(key.to_s) ? key.to_s : DEFAULT
    @now = now
    today = now.in_time_zone(zone).to_date
    @days =
      case @key
      when "this_month" then today.all_month
      when "last_month" then today.prev_month.all_month
      when "last_90_days" then (today - 89)..today
      end
    @range = days.first.in_time_zone(zone)...(days.last + 1).in_time_zone(zone)
  end

  # Whether it's still going on: its numbers may still change.
  def current?
    range.cover?(@now)
  end

  # Names the period's days, so this month's key changes when the month does.
  def cache_key
    "#{key}/#{days.first.iso8601}"
  end
end
