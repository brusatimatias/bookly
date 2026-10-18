# The customer's page for an appointment: its status, the business's reason
# when it rejected or cancelled it, its details and what the customer can
# still do (cancel it, or reschedule a confirmed one, within the business's
# cancellation window). As .ics, a confirmed appointment for their calendar.
class AppointmentsController < ApplicationController
  include AppointmentByToken

  def show
    respond_to do |format|
      format.html { set_status_details }
      format.ics { send_calendar }
    end
  end

  private
    def set_status_details
      events = @appointment.events.to_a
      last_change = events.reverse.find { |event| event.to_status == @appointment.status }
      # Why the business rejected or cancelled it.
      @reason = last_change.note if last_change&.user? && (@appointment.rejected? || @appointment.cancelled?)
      @cancelled_by_customer = @appointment.cancelled? && last_change&.customer?
      @rescheduled_from = @appointment.rescheduled_from
      @reassigned = @appointment.active? && events.any?(&:reassignment?)
    end

    def send_calendar
      raise ActiveRecord::RecordNotFound unless @appointment.confirmed?

      calendar = AppointmentCalendar.new(@appointment, url: appointment_url(token: appointment_token))
      send_data calendar.to_ical, filename: calendar.filename, type: :ics
    end
end
