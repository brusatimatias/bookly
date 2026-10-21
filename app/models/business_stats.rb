# The numbers of the statistics page: what a member sees of the current
# business in a period (StatsPeriod). Owners and admins see every appointment,
# professionals their own (Membership#visible_appointments).
#
# Each number is an aggregate query, and #to_h returns plain values (no
# records), so the result can be cached as is. Times are counted in the
# business's time zone; appointments belong to the period they start in.
class BusinessStats
  TOP_SERVICES = 5
  # The team's answers to a request.
  ANSWER_STATUSES = %w[confirmed rejected].freeze

  def initialize(membership, period)
    @membership = membership
    @period = period
    @zone = Time.find_zone!(Current.business!.time_zone)
  end

  def to_h
    {
      outcomes: outcomes,
      no_show_rate: no_show_rate,
      revenue_cents: in_period.attended.sum(:price_cents),
      top_services: top_services,
      occupancy: occupancy,
      peak_hours: peak_hours,
      customers: customers,
      response_time: response_time
    }
  end

  private
    attr_reader :membership, :period, :zone

    def appointments
      @appointments ||= membership.visible_appointments
    end

    def in_period
      appointments.where(starts_at: period.range)
    end

    # Appointments that took or hold a professional's time.
    def booked
      in_period.on_agenda
    end

    # How many appointments ended (or stand) in each status, every status listed.
    def outcomes
      Appointment.statuses.keys.index_with(0).merge(in_period.group(:status).count)
    end

    # Of the appointments whose attendance was marked, the share the customer
    # missed (nil when there are none).
    def no_show_rate
      attended, no_show = outcomes.values_at("attended", "no_show")
      no_show.fdiv(attended + no_show) if attended + no_show > 0
    end

    # The most requested services, with what their attended appointments made.
    def top_services
      in_period.joins(:service).group("services.id", "services.name")
        .order(Arel.sql("COUNT(*) DESC"), "services.name").limit(TOP_SERVICES)
        .pluck("services.name", Arel.sql("COUNT(*)"),
          Arel.sql("SUM(CASE WHEN appointments.status = 'attended' THEN appointments.price_cents ELSE 0 END)"))
        .map { |name, count, revenue_cents| { name: name, count: count, revenue_cents: revenue_cents } }
    end

    # For each professional, the booked minutes against the minutes they work in
    # the period: their current weekly hours on each day, less their blocks.
    # The hours of past days aren't kept, so it's an approximation.
    def occupancy
      booked_minutes = booked.group(:professional_id).sum(Arel.sql("EXTRACT(EPOCH FROM ends_at - starts_at) / 60"))
      hours = WorkingHour.where(professional: professionals).group_by(&:professional_id)
      blocks = TimeBlock.where(professional: professionals).overlapping(period.range).group_by(&:professional_id)

      professionals.order(:name).map do |professional|
        available = available_minutes(hours.fetch(professional.id, []), blocks.fetch(professional.id, []))
        minutes = booked_minutes.fetch(professional.id, 0).to_i
        { name: professional.name, booked_minutes: minutes, available_minutes: available,
          rate: (minutes.fdiv(available) if available > 0) }
      end
    end

    # Managers see every active professional and anyone with appointments in the
    # period; professionals, their own profile.
    def professionals
      @professionals ||=
        if membership.manager?
          Professional.active.or(Professional.where(id: in_period.select(:professional_id)))
        else
          Professional.where(id: membership.professional_profile)
        end
    end

    def available_minutes(working_hours, blocks)
      period.days.sum do |day|
        working_hours.select { |hour| hour.day_of_week == day.wday }.sum do |hour|
          range = local_time(day, hour.start_time)...local_time(day, hour.end_time)
          blocked = blocks.sum { |block| overlap_seconds(range, block.range) }
          (range.end - range.begin - blocked) / 60
        end
      end.to_i
    end

    def local_time(day, time)
      zone.local(day.year, day.month, day.day, time.hour, time.min)
    end

    def overlap_seconds(range, other)
      [ [ range.end, other.end ].min - [ range.begin, other.begin ].max, 0 ].max
    end

    # Booked appointments by local weekday (0 = Sunday) and hour: { [1, 10] => 4 }.
    def peak_hours
      local = "(appointments.starts_at AT TIME ZONE 'UTC') AT TIME ZONE #{Appointment.connection.quote(zone.tzinfo.identifier)}"
      booked.group(Arel.sql("EXTRACT(DOW FROM #{local})::int"), Arel.sql("EXTRACT(HOUR FROM #{local})::int")).count
    end

    # Customers with booked appointments in the period: new ones had none before
    # it (among the appointments the member sees), returning ones did.
    def customers
      first_visits = appointments.on_agenda.where(customer_id: booked.select(:customer_id))
        .group(:customer_id).minimum(:starts_at).values
      new_customers = first_visits.count { |first| first >= period.range.begin }
      { new: new_customers, returning: first_visits.size - new_customers }
    end

    # How long the team took to confirm or reject the requests it answered in
    # the period: the median, in seconds, from the moment the appointment became
    # pending (a new request or a customer's change of time). Reassignments keep
    # it pending, so they don't restart the clock.
    def response_time
      steps = AppointmentEvent.where(appointment_id: appointments.select(:id))
        .where("(to_status = 'pending' AND from_status IS DISTINCT FROM 'pending') OR " \
               "(from_status = 'pending' AND to_status IN (:answers) AND actor_kind = 'user')", answers: ANSWER_STATUSES)
        .select(:to_status, :created_at, "LAG(created_at) OVER (PARTITION BY appointment_id ORDER BY created_at, id) AS pending_since")

      row = AppointmentEvent.connection.select_one(AppointmentEvent.sanitize_sql([ <<~SQL, answers: ANSWER_STATUSES, from: period.range.begin, to: period.range.end ]))
        SELECT COUNT(*) AS answered,
               PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM created_at - pending_since)) AS median_seconds
        FROM (#{steps.to_sql}) steps
        WHERE to_status IN (:answers) AND pending_since IS NOT NULL AND created_at >= :from AND created_at < :to
      SQL
      { answered: row["answered"], median_seconds: row["median_seconds"]&.round }
    end
end
