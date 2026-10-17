# What customers hear about their appointments, with their personal link.
# CustomerAppointmentsMailer.with(business:, appointment_id:).requested
class CustomerAppointmentsMailer < BusinessMailer
  before_action :set_appointment

  def requested
    mail_to_customer
  end

  private
    def set_appointment
      @appointment = Appointment.includes(:service, :professional, :customer).find(params.fetch(:appointment_id))
      @appointment_url = appointment_url(@business, @appointment.generate_token_for(:management))
    end

    def mail_to_customer
      customer = @appointment.customer
      mail to: email_address_with_name(customer.email, customer.name), subject: t(".subject", business: @business.name)
    end
end
