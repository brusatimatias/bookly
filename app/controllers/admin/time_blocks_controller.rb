# Periods in which professionals can't be booked. Owners and admins manage
# every professional's blocks; professionals only their own profile's.
class Admin::TimeBlocksController < Admin::BaseController
  before_action :require_profile, except: :index
  before_action :set_time_block, only: %i[edit update destroy]
  before_action :set_professionals, only: %i[index new create edit update]

  def index
    @time_blocks = time_blocks.upcoming.includes(professional: { photo_attachment: :blob })
    @professional = @professionals.find { |professional| professional.id == params[:professional_id].to_i } if params[:professional_id].present?
    @time_blocks = @time_blocks.where(professional: @professional) if @professional
  end

  def new
    @time_block = TimeBlock.new(professional: own_profile)
  end

  def create
    @time_block = TimeBlock.new(time_block_params)

    if @time_block.save
      redirect_to admin_time_blocks_path, notice: t(".created", name: @time_block.professional.name)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @time_block.assign_dates_from_range
  end

  def update
    if @time_block.update(time_block_params)
      redirect_to admin_time_blocks_path, notice: t(".updated", name: @time_block.professional.name)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @time_block.destroy!
    redirect_to admin_time_blocks_path, notice: t(".destroyed", name: @time_block.professional.name), status: :see_other
  end

  private
    # A professional's own profile, if they have one.
    def own_profile
      return @own_profile if defined?(@own_profile)

      @own_profile = Current.membership.professional_profile
    end

    def require_profile
      redirect_to admin_time_blocks_path, alert: t("admin.time_blocks.no_profile") unless Current.membership.manager? || own_profile
    end

    def time_blocks
      Current.membership.manager? ? Current.business.time_blocks : Current.business.time_blocks.where(professional: own_profile)
    end

    def set_time_block
      @time_block = time_blocks.find(params[:id])
    end

    # Professionals a manager can block: the active ones, plus the one of the
    # block being edited.
    def set_professionals
      return @professionals = [ own_profile ].compact unless Current.membership.manager?

      @professionals = Current.business.professionals.where(active: true)
        .or(Current.business.professionals.where(id: @time_block&.professional_id))
        .order(Professional.arel_table[:name].lower).to_a
    end

    # Professionals always block their own profile; managers pick one of the
    # business's (anything else leaves the block without a professional).
    def time_block_params
      attributes = params.expect(time_block: %i[professional_id all_day start_date end_date starts_at ends_at reason])
      professional_id = attributes.delete(:professional_id)
      attributes.merge(professional: Current.membership.manager? ? Current.business.professionals.find_by(id: professional_id) : own_profile)
    end
end
