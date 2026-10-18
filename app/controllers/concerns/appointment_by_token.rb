# The customer's pages of an appointment, reached through its management token
# (the personal link; customers have no account). Only this business's
# appointments are found: a token from another one, or a tampered one, is a
# 404. A change that no longer applies (the window closed, the business
# answered meanwhile) goes back to the appointment's page with an alert.
module AppointmentByToken
  extend ActiveSupport::Concern

  included do
    include SetCurrentBusiness
    allow_unauthenticated_access

    helper_method :appointment_token
    before_action :set_appointment
    rescue_from Appointment::InvalidTransition, with: :change_failed
  end

  private
    def appointment_token
      params[:appointment_token] || params[:token]
    end

    def set_appointment
      @appointment = Appointment.includes(:service, :professional, :customer).find_by_token_for(:management, appointment_token) or
        raise ActiveRecord::RecordNotFound
    end

    def change_failed
      redirect_to appointment_path(token: appointment_token), alert: t("appointments.change_failed")
    end
end
