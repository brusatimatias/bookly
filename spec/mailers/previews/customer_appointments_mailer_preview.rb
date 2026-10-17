# Previews at /rails/mailers/customer_appointments_mailer (development), built
# from the seeded appointments.
class CustomerAppointmentsMailerPreview < ActionMailer::Preview
  def requested
    mailer_for { Appointment.pending }.requested
  end

  private
    # The mailer for the latest appointment the block's scope finds, in
    # whichever business.
    def mailer_for(&scope)
      appointment = BusinessScoped.across_businesses { scope.call.order(:created_at).last } or raise "No appointment to preview: run bin/rails db:seed"
      CustomerAppointmentsMailer.with(business: appointment.business, appointment_id: appointment.id)
    end
end
