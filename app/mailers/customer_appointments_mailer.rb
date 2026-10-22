# What customers hear about their appointments: one email per change, all with
# the same template (a message, the business's reason when there is one, the
# details, a button and a closing note). A confirmed appointment comes with its
# .ics, and one that leaves the customer's calendar (cancelled, or moved back
# to a request) with a cancellation for it. Sent by AppointmentNotifier:
# CustomerAppointmentsMailer.with(business:, appointment_id:, event_id:).confirmed
class CustomerAppointmentsMailer < BusinessMailer
  include AppointmentMail
  include PublicUrlsHelper

  before_action do
    @appointment_url = appointment_url(@appointment.generate_token_for(:management), public_url_options(@business))
    @button = [ t("customer_appointments_mailer.view"), @appointment_url ]
  end

  def requested
    @body = t(".body", business: @business.name, deadline: l(@appointment.request_expires_at, format: :weekday_hour))
    @footer = t(".footer")
    mail_to_customer
  end

  def confirmed
    @body = t(".body", business: @business.name)
    @footer = changes_footer
    attach_calendar
    mail_to_customer
  end

  def rejected
    @body = t(".body", business: @business.name)
    @reason = @event.note
    offer_new_booking
    mail_to_customer
  end

  # By the business (with its reason), or by the customer: a receipt for a
  # withdrawn request or a cancelled appointment.
  def cancelled
    kind = if !@event.customer? then "by_business" elsif @event.from_status == "pending" then "withdrawn" else "by_customer" end
    @body = t(".#{kind}.body", business: @business.name)
    @reason = @event.note unless @event.customer?
    offer_new_booking
    attach_calendar(cancelled: true) if @event.from_status == "confirmed"
    mail_to_customer t(".#{kind}.subject", business: @business.name)
  end

  def expired
    @body = t(".body", business: @business.name)
    offer_new_booking
    mail_to_customer
  end

  # The customer asked for another time: it's a request again, and the old
  # time is already gone (the attached cancellation takes it off their
  # calendar; the confirmation of the new one brings it back).
  def rescheduled
    @body = t(".body", from: l(@event.from_starts_at, format: :weekday_hour), business: @business.name,
                       deadline: l(@appointment.request_expires_at, format: :weekday_hour))
    @footer = t(".footer", business: @business.name)
    attach_calendar(cancelled: true)
    mail_to_customer
  end

  def reassigned
    @body = t(".body", business: @business.name, professional: @appointment.professional.name)
    if @appointment.confirmed?
      @footer = changes_footer
      attach_calendar
    else
      @footer = t("customer_appointments_mailer.requested.footer")
    end
    mail_to_customer
  end

  # Before the appointment (SendRemindersJob), with its .ics. Nothing is sent
  # if it was cancelled or moved meanwhile.
  def reminder
    return unless @appointment.confirmed?

    @body = t(".body", business: @business.name, time: l(@appointment.starts_at, format: :weekday_hour))
    @footer = changes_footer
    attach_calendar
    mail_to_customer t(".subject", business: @business.name, time: l(@appointment.starts_at, format: :weekday_hour))
  end

  private
    # Until when the customer may cancel or reschedule on their own.
    def changes_footer
      if @appointment.customer_can_reschedule?
        t("customer_appointments_mailer.changes.open", deadline: l(@appointment.customer_deadline, format: :weekday_hour))
      else
        t("customer_appointments_mailer.changes.closed", business: @business.name)
      end
    end

    # For an appointment that's over: the button books again the same service.
    def offer_new_booking
      @button = [ t("customer_appointments_mailer.book_again"), new_booking_url(**public_url_options(@business), service_id: @appointment.service_id) ]
    end

    def attach_calendar(cancelled: false)
      calendar = AppointmentCalendar.new(@appointment, url: @appointment_url, cancelled: cancelled)
      attachments[calendar.filename] = { mime_type: "text/calendar", content: calendar.to_ical }
    end

    def mail_to_customer(subject = t(".subject", business: @business.name))
      customer = @appointment.customer
      mail to: email_address_with_name(customer.email, customer.name), subject: subject, template_name: "appointment"
    end
end
