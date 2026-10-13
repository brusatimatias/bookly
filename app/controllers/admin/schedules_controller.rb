# A professional's weekly hours, edited as a whole week. Owners and admins
# manage them; professionals only manage their own blocks.
class Admin::SchedulesController < Admin::BaseController
  before_action :require_manager
  before_action :set_schedule

  def edit
  end

  def update
    if @schedule.update(ranges_params)
      redirect_to admin_professionals_path, notice: t(".updated", name: @schedule.professional.name)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_schedule
      @schedule = WeeklySchedule.new(Current.business.professionals.find(params[:professional_id]))
    end

    # Every range of the week; none when the professional doesn't work at all.
    def ranges_params
      params.fetch(:schedule, {}).permit(ranges: %i[day_of_week start_time end_time]).fetch(:ranges, []).map(&:to_h)
    end
end
