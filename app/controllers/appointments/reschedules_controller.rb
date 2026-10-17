# The customer moving a confirmed appointment to another time from their
# personal link, until the business's cancellation window closes: they pick a
# free time in the week view (?week=, as in the booking flow), confirm it, and
# the appointment goes back to pending (AppointmentReschedule). The service
# stays the same, and so does the professional unless the customer had asked
# for any.
class Appointments::ReschedulesController < ApplicationController
  include AppointmentByToken
  include AvailabilityWeek

  rate_limit to: 10, within: 10.minutes, only: :create, with: -> {
    redirect_to appointment_path(token: appointment_token), alert: t("appointments.rate_limited")
  }

  before_action :require_reschedulable, :set_availability

  def new
    @slot = requested_slot
    load_week unless @slot
  end

  def create
    @slot = requested_slot
    return redirect_to new_appointment_reschedule_path(appointment_token: appointment_token, week: requested_start&.to_date), alert: t(".slot_taken") unless @slot

    @reschedule = AppointmentReschedule.new(appointment: @appointment, availability: @availability, starts_at: @slot.starts_at)
    if @reschedule.save
      redirect_to appointment_path(token: appointment_token), notice: t(".requested")
    elsif @reschedule.slot_taken?
      redirect_to new_appointment_reschedule_path(appointment_token: appointment_token, week: @slot.starts_at.to_date), alert: t(".slot_taken")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def require_reschedulable
      change_failed unless @appointment.customer_can_reschedule?
    end

    # Its own time counts as free, so it can move to an overlapping one.
    def set_availability
      professional = @appointment.professional unless @appointment.any_professional?
      @availability = Availability.new(@appointment.service, professional: professional, except: @appointment)
    end

    def requested_start
      Time.zone.iso8601(params[:starts_at].to_s) rescue nil
    end

    # The free slot at the requested start, unless it's the current one.
    def requested_slot
      starts_at = requested_start
      return if starts_at.nil? || starts_at == @appointment.starts_at

      slot = @availability.slot_at(starts_at)
      flash.now[:alert] = t("appointments.reschedules.create.slot_taken") unless slot
      slot
    end

    # The week to pick from, without the current time.
    def load_week
      load_availability_week(@availability, date: params[:week] || requested_start&.to_date || @appointment.starts_at.to_date)
      @days = @days.transform_values { |slots| slots.reject { |slot| slot.starts_at == @appointment.starts_at } }
    end
end
