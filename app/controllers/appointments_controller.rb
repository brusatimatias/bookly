# The customer's page for an appointment, reached through its management token
# (the personal link; customers have no account): its status, the business's
# reason when it rejected or cancelled it, and its details. Read only for now:
# cancelling and rescheduling come with appointment management by link.
class AppointmentsController < ApplicationController
  include SetCurrentBusiness
  allow_unauthenticated_access

  def show
    # Only this business's appointments: a token from another one, or a
    # tampered one, is not found.
    @appointment = Appointment.includes(:service, :professional, :customer).find_by_token_for(:management, params[:token]) or
      raise ActiveRecord::RecordNotFound

    events = @appointment.events.to_a
    # Why the business rejected or cancelled it.
    @reason = events.reverse.find { |event| event.to_status == @appointment.status && event.user? }&.note if @appointment.rejected? || @appointment.cancelled?
    @reassigned = @appointment.active? && events.any? { |event| event.metadata.key?("to_professional_id") }
  end
end
