# For panel controllers acting on one appointment: finds it among the ones the
# member sees (404 otherwise), and turns a change that no longer applies
# (already answered, already started, expired) into an alert on its page.
module Admin::AppointmentActions
  extend ActiveSupport::Concern

  included do
    before_action :set_appointment
    rescue_from Appointment::InvalidTransition, with: :transition_failed
  end

  private
    def set_appointment
      @appointment = Current.membership.visible_appointments.find(params[:appointment_id] || params[:id])
    end

    def transition_failed
      @appointment.reload
      status = Appointment.human_attribute_name("status.#{@appointment.status}")
      redirect_to admin_appointment_path(@appointment), alert: t("admin.appointments.transition_failed", status: status.downcase)
    end
end
