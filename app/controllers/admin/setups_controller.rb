# The setup assistant, for the owner: the business's details, a first
# service, who offers it and their weekly hours, until the business's page
# takes bookings. Each step can be repeated (another service, another
# professional) and nothing about the assistant is stored: BusinessSetup reads
# the progress from the data, so the regular pages count too.
class Admin::SetupsController < Admin::BaseController
  before_action :require_owner
  before_action :set_setup

  def show
    @step = params[:step]
    return redirect_to(admin_setup_step_path(@setup.first_step)) unless @step
    return redirect_to(admin_setup_step_path(@setup.next_step)) if @step == "done" && !@setup.complete?

    prepare_step
  end

  def update
    @step = params[:step]
    send(:"update_#{@step}")
  end

  private
    def set_setup
      @setup = BusinessSetup.new
    end

    def prepare_step
      case @step
      when "details"
        @business ||= Current.business
      when "service"
        @services = Service.active.order(Service.arel_table[:name].lower)
        @service ||= Service.new(duration_minutes: 30)
      when "professional"
        @professionals = Professional.active.includes(:services).order(Professional.arel_table[:name].lower)
        @professional ||= Professional.new
        @offers_own = Current.membership.professional_profile.present?
      when "hours"
        @professionals = Professional.active.includes(:working_hours).order(Professional.arel_table[:name].lower)
        @hours ||= SetupHours.new(professionals: professionals_without_hours)
      end
    end

    def update_details
      # A copy, so the layout keeps showing the saved name if this one is invalid.
      @business = Business.find(Current.business.id)

      if @business.update(params.expect(business: %i[name contact_email contact_phone address]))
        redirect_to admin_setup_step_path("service")
      else
        render_step
      end
    end

    def update_service
      @service = Service.new(params.expect(service: %i[name duration_minutes price]))

      if @service.save
        redirect_to admin_setup_step_path("service"), notice: t(".service_added", name: @service.name)
      else
        render_step
      end
    end

    # The owner themselves (myself), or someone else by name; either way
    # offering every active service.
    def update_professional
      @professional = params[:myself] ? Professional.new(user: Current.user) : Professional.new(params.expect(professional: %i[name]))
      @professional.service_ids = Service.active.ids

      if @professional.save
        redirect_to admin_setup_step_path("professional"), notice: t(".professional_added", name: @professional.name)
      else
        render_step
      end
    end

    def update_hours
      @hours = SetupHours.new(params.expect(setup_hours: [ :start_time, :end_time, days: [] ]), professionals: professionals_without_hours)

      if @hours.save
        redirect_to admin_setup_step_path(@setup.next_step)
      else
        render_step
      end
    end

    def render_step
      prepare_step
      render :show, status: :unprocessable_entity
    end

    def professionals_without_hours
      Professional.active.where.not(id: WorkingHour.select(:professional_id)).order(Professional.arel_table[:name].lower)
    end
end
