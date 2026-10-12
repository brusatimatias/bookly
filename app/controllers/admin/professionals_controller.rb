# Bookable people of the business. Every member sees them; owners and admins
# manage them. Professionals are never deleted, only deactivated.
class Admin::ProfessionalsController < Admin::BaseController
  before_action :require_manager, except: :index
  before_action :set_professional, only: %i[edit update deactivate reactivate]
  before_action :set_form_options, only: %i[new create edit update]

  def index
    @professionals = Current.business.professionals.includes(:user, :services, photo_attachment: :blob)
      .order(active: :desc).order(Professional.arel_table[:name].lower)
  end

  def new
    @professional = Current.business.professionals.new
  end

  def create
    @professional = Current.business.professionals.new(professional_params)

    if @professional.save
      redirect_to admin_professionals_path, notice: t(".created", name: @professional.name)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @professional.update(professional_params)
      redirect_to admin_professionals_path, notice: t(".updated", name: @professional.name)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def deactivate
    @professional.deactivate!
    redirect_to admin_professionals_path, notice: t(".deactivated", name: @professional.name)
  end

  def reactivate
    @professional.reactivate!
    redirect_to admin_professionals_path, notice: t(".reactivated", name: @professional.name)
  end

  private
    def set_professional
      @professional = Current.business.professionals.find(params[:id])
    end

    # Active services, plus inactive ones the professional already offers so
    # saving the form doesn't drop them. Members that don't have a profile yet,
    # plus the one linked to this profile.
    def set_form_options
      offered_ids = @professional&.service_ids || []
      @services = Current.business.services.where(active: true).or(Current.business.services.where(id: offered_ids))
        .order(Service.arel_table[:name].lower)

      linked_user_ids = Current.business.professionals.where.not(user_id: nil).where.not(id: @professional&.id).select(:user_id)
      @members = Current.business.memberships.includes(:user).where.not(user_id: linked_user_ids)
        .map(&:user).sort_by { |user| user.name.downcase }
    end

    def professional_params
      params.expect(professional: [ :name, :photo, :user_id, service_ids: [] ])
    end
end
