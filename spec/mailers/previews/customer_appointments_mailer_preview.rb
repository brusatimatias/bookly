# Previews at /rails/mailers/customer_appointments_mailer (development), built
# from the seeded appointments: each email uses the latest event it is about.
class CustomerAppointmentsMailerPreview < ActionMailer::Preview
  def requested
    mailer_for { AppointmentEvent.where(from_status: nil).joins(:appointment).merge(Appointment.pending) }.requested
  end

  def confirmed
    mailer_for { AppointmentEvent.where(to_status: "confirmed", from_status: "pending") }.confirmed
  end

  def rejected
    mailer_for { AppointmentEvent.where(to_status: "rejected") }.rejected
  end

  def cancelled_by_business
    mailer_for { AppointmentEvent.where(to_status: "cancelled", actor_kind: "user") }.cancelled
  end

  def cancelled_by_customer
    mailer_for { AppointmentEvent.where(to_status: "cancelled", actor_kind: "customer") }.cancelled
  end

  def expired
    mailer_for { AppointmentEvent.where(to_status: "expired") }.expired
  end

  def rescheduled
    mailer_for { AppointmentEvent.where("metadata ? 'from_starts_at'") }.rescheduled
  end

  def reassigned
    mailer_for { AppointmentEvent.where("metadata ? 'to_professional_id'").where.not("metadata ? 'from_starts_at'") }.reassigned
  end

  def reminder
    mailer_for { AppointmentEvent.joins(:appointment).merge(Appointment.confirmed.where(starts_at: Time.current..)) }.reminder
  end

  private
    # The mailer for the latest event the block's scope finds, in whichever
    # business.
    def mailer_for(&scope)
      event = BusinessScoped.across_businesses { scope.call.order(:created_at).last } or raise "No such event to preview: run bin/rails db:seed"
      CustomerAppointmentsMailer.with(business: event.business, appointment_id: event.appointment_id, event_id: event.id)
    end
end
