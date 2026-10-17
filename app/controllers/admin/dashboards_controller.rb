class Admin::DashboardsController < Admin::BaseController
  def show
    @members_count = Current.business.memberships.count
    @pending_invitations_count = Current.business.invitations.pending.count
    @active_services_count = Current.business.services.active.count
    @active_professionals_count = Current.business.professionals.active.count

    appointments = Current.membership.visible_appointments.includes(:service, :customer, :events, professional: { photo_attachment: :blob })
    @requests = appointments.awaiting_answer.order(:request_expires_at, :starts_at).limit(5)
    @today = appointments.on_agenda.where(starts_at: Time.zone.today.all_day).order(:starts_at)
  end
end
