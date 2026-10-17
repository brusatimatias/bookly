# An appointment as an iCalendar (.ics) event for the customer's calendar:
# attached to the emails and downloadable from their page. The UID is fixed per
# appointment and SEQUENCE grows with each of its events, so a calendar that
# imports a newer file updates the event instead of adding another; a
# cancellation (cancelled: true) removes it. Texts are in the current locale.
class AppointmentCalendar
  def initialize(appointment, url:, cancelled: false)
    @appointment = appointment
    @url = url
    @cancelled = cancelled
  end

  def filename
    "#{I18n.t("appointment_calendar.filename")}.ics"
  end

  def to_ical
    calendar = Icalendar::Calendar.new
    calendar.prodid = "-//Bookly//Appointments//#{I18n.locale.upcase}"
    calendar.ip_method = @cancelled ? "CANCEL" : "PUBLISH"
    calendar.add_event(event)
    calendar.to_ical
  end

  private
    def event
      business = @appointment.business
      Icalendar::Event.new.tap do |event|
        event.uid = "bookly-appointment-#{@appointment.id}@#{Rails.configuration.x.mail_from.split("@").last}"
        event.sequence = @appointment.events.count
        event.dtstamp = utc(Time.current)
        event.dtstart = utc(@appointment.starts_at)
        event.dtend = utc(@appointment.ends_at)
        event.summary = I18n.t("appointment_calendar.summary", service: @appointment.service.name, business: business.name)
        event.description = I18n.t("appointment_calendar.description", professional: @appointment.professional.name, url: @url)
        event.location = business.address if business.address.present?
        event.url = @url
        event.organizer = Icalendar::Values::CalAddress.new("mailto:#{Rails.configuration.x.mail_from}", cn: business.name)
        event.status = @cancelled ? "CANCELLED" : "CONFIRMED"
      end
    end

    def utc(time)
      Icalendar::Values::DateTime.new(time.utc, "tzid" => "UTC")
    end
end
