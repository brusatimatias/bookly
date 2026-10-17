# Previews at /rails/mailers/team_appointments_mailer (development), built from
# the seeded appointments and sent to the business's owner.
class TeamAppointmentsMailerPreview < ActionMailer::Preview
  def new_request
    mailer_for { AppointmentEvent.where(from_status: nil) }.new_request
  end

  def customer_rescheduled
    mailer_for { AppointmentEvent.where("metadata ? 'from_starts_at'") }.customer_rescheduled
  end

  def customer_cancelled
    mailer_for { AppointmentEvent.where(to_status: "cancelled", actor_kind: "customer") }.customer_cancelled
  end

  private
    # The mailer for the latest event the block's scope finds, in whichever
    # business.
    def mailer_for(&scope)
      event = BusinessScoped.across_businesses { scope.call.order(:created_at).last } or raise "No such event to preview: run bin/rails db:seed"
      owner = event.business.memberships.owner.first.user
      TeamAppointmentsMailer.with(business: event.business, appointment_id: event.appointment_id, event_id: event.id, recipient: owner)
    end
end
