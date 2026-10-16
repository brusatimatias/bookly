# An appointment in the panel: its details and history, and the changes that
# need no form (confirming, attendance). Rejecting, cancelling and reassigning
# have their own controllers.
class Admin::AppointmentsController < Admin::BaseController
  include Admin::AppointmentActions

  def show
    @events = @appointment.events.includes(:actor_user).to_a
    professional_ids = @events.flat_map { |event| event.metadata.values_at("from_professional_id", "to_professional_id") }.compact
    @professional_names = Current.business.professionals.where(id: professional_ids).pluck(:id, :name).to_h
  end

  def confirm
    @appointment.confirm!(by: Current.user)
    redirect_back_or_to admin_appointment_path(@appointment), notice: t(".confirmed", customer: @appointment.customer.name)
  end

  def attended
    @appointment.mark_attended!(by: Current.user)
    redirect_to admin_appointment_path(@appointment), notice: t(".marked")
  end

  def no_show
    @appointment.mark_no_show!(by: Current.user)
    redirect_to admin_appointment_path(@appointment), notice: t(".marked")
  end
end
