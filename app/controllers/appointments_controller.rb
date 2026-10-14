# The customer's page for an appointment, reached through its management token
# (the personal link; customers have no account). Read only for now: cancelling
# and rescheduling come with appointment management by link.
class AppointmentsController < ApplicationController
  include SetCurrentBusiness
  allow_unauthenticated_access

  def show
    # Only this business's appointments: a token from another one, or a
    # tampered one, is not found.
    @appointment = Appointment.includes(:service, :professional, :customer).find_by_token_for(:management, params[:token]) or
      raise ActiveRecord::RecordNotFound
  end
end
