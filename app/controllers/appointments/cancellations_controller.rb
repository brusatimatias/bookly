# The customer withdrawing a request, or cancelling a confirmed appointment
# until the business's cancellation window closes, from their personal link.
# The reason is optional.
class Appointments::CancellationsController < ApplicationController
  include AppointmentByToken

  rate_limit to: 10, within: 10.minutes, only: :create, with: -> {
    redirect_to appointment_path(token: appointment_token), alert: t("appointments.rate_limited")
  }

  def new
    return change_failed unless @appointment.customer_can_cancel?

    @event = AppointmentEvent.new
  end

  def create
    @appointment.cancel!(by: :customer, reason: params.dig(:cancellation, :note))
    redirect_to appointment_path(token: appointment_token), notice: t(".cancelled")
  rescue ActiveRecord::RecordInvalid => error
    @event = error.record
    render :new, status: :unprocessable_entity
  end
end
