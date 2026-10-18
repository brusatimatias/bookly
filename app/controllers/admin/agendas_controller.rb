# A week of appointments (requests, confirmed ones and their attendance), Monday
# first. Owners and admins see every professional's, or one's; professionals
# their own.
class Admin::AgendasController < Admin::BaseController
  ALL_PROFESSIONALS = "all"

  def show
    @week = week
    @professionals = professionals
    @professional = @professionals.find { |professional| professional.id == params[:professional_id].to_i } if Current.membership.manager?

    appointments = Current.membership.visible_appointments.on_agenda
      .where(starts_at: @week.beginning_of_day...(@week + 7).beginning_of_day)
      .includes(:service, :customer, :professional).order(:starts_at)
    appointments = appointments.where(professional: @professional) if @professional
    @days = appointments.group_by { |appointment| appointment.starts_at.to_date }
  end

  private
    # The Monday of the requested week (?week=, any date in it), this one by default.
    def week
      date = Date.iso8601(params[:week].to_s) rescue Time.zone.today
      date.beginning_of_week
    end

    # Whose agenda managers can pick: every professional, active ones first.
    def professionals
      return [] unless Current.membership.manager?

      Current.business.professionals.order(active: :desc).order(Professional.arel_table[:name].lower).to_a
    end
end
