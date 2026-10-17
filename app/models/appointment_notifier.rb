# Emails the people an appointment's change concerns, once it's committed
# (AppointmentEvent's after_create_commit): the customer hears about every
# change except attendance. Mails are delivered by a job, so they never hold up
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
  end

  private
    attr_reader :event

    def customer_email
      action = customer_email_action or return
      CustomerAppointmentsMailer.with(business: event.business, appointment_id: event.appointment_id, event_id: event.id).public_send(action)
    end

    def customer_email_action
      if event.from_status.nil? then :requested
      elsif event.reschedule? then :rescheduled
      elsif event.reassignment? then :reassigned
      elsif event.to_status.in?(%w[confirmed rejected cancelled expired]) then event.to_status.to_sym
      end
    end
end
