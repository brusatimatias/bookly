# Emails the people an appointment's change concerns, once it's committed
# (AppointmentEvent's after_create_commit): the customer hears about every
# change except attendance, and the team (Appointment#team_recipients, one
# email each) about what the customer does; what the team does in the panel
# they already see live. Mails are delivered by a job, so they never hold up
# the request, and only for changes that were actually saved.
class AppointmentNotifier
  def self.call(event)
    new(event).call
  end

  def initialize(event)
    @event = event
  end

  def call
    customer_email&.deliver_later
    team_emails.each(&:deliver_later)
  end

  private
    attr_reader :event

    def customer_email
      action = customer_email_action or return
      CustomerAppointmentsMailer.with(business: event.business, appointment_id: event.appointment_id, event_id: event.id).public_send(action)
    end

    def team_emails
      action = team_email_action or return []
      event.appointment.team_recipients.map do |recipient|
        TeamAppointmentsMailer.with(business: event.business, appointment_id: event.appointment_id, event_id: event.id, recipient: recipient)
          .public_send(action)
      end
    end

    def team_email_action
      return unless event.customer?

      if event.from_status.nil? then :new_request
      elsif event.reschedule? then :customer_rescheduled
      elsif event.to_status == "cancelled" then :customer_cancelled
      end
    end

    def customer_email_action
      if event.from_status.nil? then :requested
      elsif event.reschedule? then :rescheduled
      elsif event.reassignment? then :reassigned
      elsif event.to_status.in?(%w[confirmed rejected cancelled expired]) then event.to_status.to_sym
      end
    end
end
