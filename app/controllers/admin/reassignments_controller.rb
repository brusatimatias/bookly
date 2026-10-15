# Moving an appointment that hasn't started to another professional. Owners and
# admins only.
class Admin::ReassignmentsController < Admin::BaseController
  include Admin::AppointmentActions

  before_action :require_manager
  before_action :set_candidates

  def new
    transition_failed unless @appointment.active? && !@appointment.started?
  end

  def create
    professional = @candidates.find { |candidate| candidate.id == params.dig(:reassignment, :professional_id).to_i }
    if professional.nil?
      @appointment.errors.add(:professional, :blank)
      return render :new, status: :unprocessable_entity
    end

    @appointment.reassign!(professional, by: Current.user)
    redirect_to admin_appointment_path(@appointment), notice: t(".reassigned", name: professional.name)
  rescue ActiveRecord::RecordInvalid
    # Back to the assigned professional; the errors and the choice stay.
    @appointment.restore_attributes
    render :new, status: :unprocessable_entity
  end

  private
    # Active professionals offering the service, other than the assigned one.
    def set_candidates
      @candidates = @appointment.service.professionals.active.where.not(id: @appointment.professional_id)
        .order(Professional.arel_table[:name].lower).to_a
    end
end
