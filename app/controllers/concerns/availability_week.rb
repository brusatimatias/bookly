# Browsing free times one week at a time (panel preview and public booking):
# the requested week (?week=, any date in it), kept within the booking window,
# its free times and, when the whole week is empty, the next free day.
module AvailabilityWeek
  private
    def load_availability_week(availability, date: params[:week])
      requested = Date.iso8601(date.to_s) rescue availability.first_day

      @availability = availability
      @week = requested.clamp(availability.first_day, availability.last_day).beginning_of_week
      @days = availability.days(@week..(@week + 6))
      @next_free_day = availability.next_free_day(after: @week + 6) if @days.values.none?(&:any?)
    end
end
