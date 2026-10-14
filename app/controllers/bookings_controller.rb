# Public booking flow: customers pick a service, a professional (or any) and a
# free time, one step at a time. The choices travel in the URL (service_id,
# professional_id, which can be "any", and starts_at), so going back and
# sharing a link just work; anything invalid or no longer free sends them back
# to the step that needs it. The last step sends the request
# (AppointmentRequest).
class BookingsController < ApplicationController
  include SetCurrentBusiness
  include AvailabilityWeek
  allow_unauthenticated_access

  ANY_PROFESSIONAL = "any"

  rate_limit to: 10, within: 10.minutes, only: :create, with: -> {
    redirect_to new_booking_path(params.slice(:service_id, :professional_id, :starts_at).permit!), alert: t("bookings.create.rate_limited")
  }

  def new
    @step = current_step
    load_availability_week(@availability, date: params[:week] || @requested_start&.to_date) if @step == :time
    @appointment_request = AppointmentRequest.new(availability: @availability, starts_at: @slot.starts_at) if @step == :details
  end

  def create
    # Something changed since the customer chose (the time was taken, the
    # service is no longer offered): the form's step explains it.
    return redirect_to new_booking_path(choices(starts_at: params[:starts_at])) unless current_step == :details

    @step = :details
    @appointment_request = AppointmentRequest.new(availability: @availability, starts_at: @slot.starts_at, **appointment_request_params)
    if @appointment_request.save
      redirect_to business_path(Current.business), notice: t(".requested")
    elsif @appointment_request.slot_taken?
      redirect_to new_booking_path(choices(week: @slot.starts_at.to_date)), alert: t("bookings.new.slot_taken")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    # Fills in the choices made so far and returns the first step missing.
    def current_step
      @services = bookable_services
      @service = @services.find { |service| service.id == params[:service_id].to_i }
      return :service unless @service

      @professionals = @service.professionals.merge(Professional.bookable).order(Professional.arel_table[:name].lower).to_a
      # Nothing to choose with a single professional.
      @professional = @professionals.one? ? @professionals.first : @professionals.find { |professional| professional.id == params[:professional_id].to_i }
      @any_professional = @professional.nil? && params[:professional_id] == ANY_PROFESSIONAL
      return :professional unless @professional || @any_professional

      @availability = Availability.new(@service, professional: @professional)
      @slot = requested_slot
      @slot ? :details : :time
    end

    # Bookable services; only the chosen professional's when the customer
    # started from one.
    def bookable_services
      services = Current.business.services.bookable.with_rich_text_description.order(Service.arel_table[:name].lower)
      @starting_professional = Current.business.professionals.bookable.find_by(id: params[:professional_id]) if params[:service_id].blank?
      @starting_professional ? services.where(id: @starting_professional.service_ids) : services
    end

    # The free slot at the requested start, if it is still free.
    def requested_slot
      @requested_start = Time.zone.iso8601(params[:starts_at].to_s) rescue nil
      return unless @requested_start

      slot = @availability.days(@requested_start.to_date..@requested_start.to_date)
        .fetch(@requested_start.to_date, []).find { |slot| slot.starts_at == @requested_start }
      flash.now[:alert] = t("bookings.new.slot_taken") unless slot
      slot
    end

    def appointment_request_params
      params.expect(appointment_request: %i[name email phone customer_notes]).to_h.symbolize_keys
    end

    helper_method :choices
    # The URL parameters for the choices made so far, to build each step's links.
    def choices(**overrides)
      { service_id: @service&.id, professional_id: @professional&.id || (ANY_PROFESSIONAL if @any_professional) }.merge(overrides).compact
    end
end
