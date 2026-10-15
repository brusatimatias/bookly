# Turning down a request, with the reason the customer will read.
class Admin::RejectionsController < Admin::BaseController
  include Admin::AppointmentActions

  def new
    return transition_failed unless @appointment.pending?

    @event = AppointmentEvent.new
  end

  def create
    @appointment.reject!(by: Current.user, reason: params.dig(:rejection, :note))
    redirect_to admin_requests_path, notice: t(".rejected", customer: @appointment.customer.name)
  rescue ActiveRecord::RecordInvalid => error
    @event = error.record
    render :new, status: :unprocessable_entity
  end
end
