# The business cancelling a confirmed appointment before it starts, with the
# reason the customer will read.
class Admin::CancellationsController < Admin::BaseController
  include Admin::AppointmentActions

  def new
    return transition_failed unless @appointment.confirmed? && !@appointment.started?

    @event = AppointmentEvent.new
  end

  def create
    @appointment.cancel!(by: Current.user, reason: params.dig(:cancellation, :note))
    redirect_to admin_appointment_path(@appointment), notice: t(".cancelled", customer: @appointment.customer.name)
  rescue ActiveRecord::RecordInvalid => error
    @event = error.record
    render :new, status: :unprocessable_entity
  end
end
