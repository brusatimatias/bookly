# Services the business offers. Every member sees them; owners and admins
# manage them. Services are never deleted, only deactivated.
class Admin::ServicesController < Admin::BaseController
  before_action :require_manager, except: :index
  before_action :set_service, only: %i[edit update deactivate reactivate]

  def index
    @services = Current.business.services.includes(:professionals).order(active: :desc).order(Service.arel_table[:name].lower)
  end

  def new
    @service = Current.business.services.new
  end

  def create
    @service = Current.business.services.new(service_params)

    if @service.save
      redirect_to admin_services_path, notice: t(".created", name: @service.name)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @service.update(service_params)
      redirect_to admin_services_path, notice: t(".updated", name: @service.name)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def deactivate
    @service.deactivate!
    redirect_to admin_services_path, notice: t(".deactivated", name: @service.name)
  end

  def reactivate
    @service.reactivate!
    redirect_to admin_services_path, notice: t(".reactivated", name: @service.name)
  end

  private
    def set_service
      @service = Current.business.services.find(params[:id])
    end

    def service_params
      params.expect(service: %i[name description duration_minutes price buffer_minutes])
    end
end
