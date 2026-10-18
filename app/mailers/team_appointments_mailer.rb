# What the team hears about what customers do: new requests, changes of time
# and cancellations, one email per member, with a link to the appointment in
# the panel. Replies go to the customer. Sent by AppointmentNotifier:
# TeamAppointmentsMailer.with(business:, appointment_id:, event_id:, recipient:).new_request
class TeamAppointmentsMailer < BusinessMailer
  include AppointmentMail

  def new_request
    @body = t(".body", customer: customer.name, deadline: l(@appointment.request_expires_at, format: :weekday_hour))
    mail_to_recipient t(".subject", customer: customer.name, time: l(@appointment.starts_at, format: :weekday_hour))
  end

  def customer_rescheduled
    @body = t(".body", customer: customer.name, from: l(@event.from_starts_at, format: :weekday_hour),
                       to: l(@event.to_starts_at, format: :weekday_hour), deadline: l(@appointment.request_expires_at, format: :weekday_hour))
    mail_to_recipient t(".subject", customer: customer.name)
  end

  # A withdrawn request or a cancelled appointment, with the customer's reason
  # if they gave one.
  def customer_cancelled
    kind = @event.from_status == "pending" ? "withdrawn" : "cancelled"
    time = l(@appointment.starts_at, format: :weekday_hour)
    @body = t(".#{kind}.body", customer: customer.name, time: time)
    @reason = @event.note
    mail_to_recipient t(".#{kind}.subject", customer: customer.name, time: time)
  end

  private
    def customer
      @appointment.customer
    end

    def mail_to_recipient(subject)
      @recipient = params.fetch(:recipient)
      mail to: email_address_with_name(@recipient.email_address, @recipient.name), reply_to: email_address_with_name(customer.email, customer.name),
           subject: subject, template_name: "appointment"
    end
end
