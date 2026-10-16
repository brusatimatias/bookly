# Free start times for a service in the current business: the professionals'
# weekly hours, minus their blocks and active appointments, within the
# business's booking rules.
#
# - Start times are counted from the beginning of each working range, every
#   slot_interval_minutes (09:15, 09:45, ... for a range starting at 09:15).
# - The whole service must fit in the range; the break after it may run past
#   its end.
# - The service can't overlap a block. Service plus break can't overlap an
#   active appointment's time plus break (as the database's exclusion
#   constraint checks it).
# - From now plus min_booking_notice_hours, up to booking_horizon_days from
#   today (whole days, in the business's time zone).
#
# Without a professional it looks at every bookable professional offering the
# service ("any professional"); each slot lists who is free then.
#
# `except` is an appointment whose time doesn't count as busy: the one a
# customer is moving to another time.
class Availability
  Slot = Data.define(:starts_at, :professionals)

  attr_reader :service, :professional, :except, :business, :zone, :now

  def initialize(service, professional: nil, except: nil, now: Time.current)
    @service = service
    @professional = professional
    @except = except
    # The current one (the service belongs to it): fails closed without one,
    # and always has its latest booking rules.
    @business = Current.business!
    @zone = Time.find_zone!(business.time_zone)
    @now = now.in_time_zone(zone)
  end

  # The first start time customers may book.
  def earliest_start
    now + business.min_booking_notice_hours.hours
  end

  def first_day
    earliest_start.to_date
  end

  def last_day
    now.to_date + business.booking_horizon_days
  end

  def bookable_day?(date)
    date.between?(first_day, last_day)
  end

  # Whether any of the professionals has working hours that weekday.
  def works_on?(date)
    professionals.any? { |candidate| candidate.working_hours.any? { |range| range.day_of_week == date.wday } }
  end

  # The first day with free slots after the given one, looking up to `within`
  # days ahead (never past the booking window); nil if there is none.
  def next_free_day(after:, within: 60)
    from = [ after + 1, first_day ].max
    to = [ after + within, last_day ].min
    return if from > to

    days(from..to).find { |_date, slots| slots.any? }&.first
  end

  # Free slots of each day in dates (a range of Date), keeping only the days
  # within the booking window: { date => [Slot, ...] } in order.
  def days(dates)
    dates = [ dates.first, first_day ].max..[ dates.last, last_day ].min
    return {} if dates.none? || professionals.empty?

    window = zone.local(dates.first.year, dates.first.month, dates.first.day)...zone.local(dates.last.year, dates.last.month, dates.last.day) + 1.day
    load_busy_times(window)

    dates.index_with { |date| slots_on(date) }
  end

  # The free slot starting at starts_at, if there is one.
  def slot_at(starts_at)
    date = starts_at.in_time_zone(zone).to_date
    days(date..date).fetch(date, []).find { |slot| slot.starts_at == starts_at }
  end

  # Who is free at starts_at; with several, the least busy that day first
  # (then by name), to spread the work for "any professional".
  def candidates(starts_at)
    free = slot_at(starts_at)&.professionals || []
    return free if free.size < 2

    midnight = starts_at.in_time_zone(zone).beginning_of_day
    busy = Appointment.active.where(professional_id: free.map(&:id), starts_at: midnight...(midnight + 1.day)).group(:professional_id).count
    free.sort_by { |candidate| [ busy.fetch(candidate.id, 0), candidate.name.downcase ] }
  end

  # Professionals customers can book for the service: the given one, or any.
  def professionals
    @professionals ||= begin
      scope = service.active? ? service.professionals.merge(Professional.bookable) : Professional.none
      scope = scope.where(id: professional.id) if professional
      scope.includes(:working_hours).order(Professional.arel_table[:name].lower).to_a
    end
  end

  private
    def duration
      service.duration_minutes.minutes
    end

    def buffer
      service.effective_buffer_minutes.minutes
    end

    def interval
      business.slot_interval_minutes.minutes
    end

    # Blocks and active appointments of the professionals around the window,
    # grouped by professional: three queries in total, whatever the range.
    def load_busy_times(window)
      search = (window.begin - 1.day)...(window.end + 1.day)
      ids = professionals.map(&:id)

      @blocks = TimeBlock.where(professional_id: ids).overlapping(search).group_by(&:professional_id)
      appointments = Appointment.active.where(professional_id: ids).overlapping(search)
      appointments = appointments.where.not(id: except.id) if except
      @appointments = appointments.group_by(&:professional_id)
    end

    def slots_on(date)
      free = Hash.new { |hash, starts_at| hash[starts_at] = [] }

      professionals.each do |candidate|
        candidate.working_hours.select { |range| range.day_of_week == date.wday }.each do |range|
          start_times(date, range).each { |starts_at| free[starts_at] << candidate if free?(candidate, starts_at) }
        end
      end

      free.sort.map { |starts_at, available| Slot.new(starts_at: starts_at, professionals: available) }
    end

    # Every start in the range where the whole service fits.
    def start_times(date, range)
      starts_at = local_time(date, range.start_time)
      ends_at = local_time(date, range.end_time)

      times = []
      while starts_at + duration <= ends_at
        times << starts_at
        starts_at += interval
      end
      times
    end

    def local_time(date, time)
      zone.local(date.year, date.month, date.day, time.hour, time.min)
    end

    def free?(candidate, starts_at)
      return false if starts_at < earliest_start || starts_at.to_date > last_day

      service_time = starts_at...(starts_at + duration)
      busy_time = starts_at...(starts_at + duration + buffer)

      @blocks.fetch(candidate.id, []).none? { |block| block.range.overlap?(service_time) } &&
        @appointments.fetch(candidate.id, []).none? { |appointment| appointment.busy_range.overlap?(busy_time) }
    end
end
