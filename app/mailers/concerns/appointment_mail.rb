# Loads the appointment, and the event the email is about, from the mailer's
# params (appointment_id:, event_id:), within the business BusinessMailer sets.
module AppointmentMail
  extend ActiveSupport::Concern

  included do
    before_action :set_appointment
  end

  private
    def set_appointment
      @appointment = Appointment.includes(:service, :professional, :customer).find(params.fetch(:appointment_id))
      @event = @appointment.events.find(params[:event_id]) if params[:event_id]
    end
end
