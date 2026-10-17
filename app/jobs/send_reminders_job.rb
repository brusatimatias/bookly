# Emails customers a reminder before their confirmed appointments, in every
# business (Appointment.due_for_reminder). Runs every 5 minutes
# (config/recurring.yml); each appointment is marked before its email is
# enqueued, and only if nobody marked it meanwhile, so a reminder is never sent
# twice.
class SendRemindersJob < ApplicationJob
  queue_as :default

  def perform
    due_by_business.each do |business, appointment_ids|
      Current.set(business: business) do
        appointment_ids.each do |appointment_id|
          marked = Appointment.where(id: appointment_id, reminder_sent_at: nil).update_all(reminder_sent_at: Time.current)
          CustomerAppointmentsMailer.with(business: business, appointment_id: appointment_id).reminder.deliver_later if marked == 1
        end
      end
    end
  end

  private
    # { business => [appointment id, ...] } for the reminders due.
    def due_by_business
      rows = BusinessScoped.across_businesses { Appointment.due_for_reminder.pluck(:business_id, :id) }
      businesses = Business.where(id: rows.map(&:first)).index_by(&:id)

      rows.group_by(&:first).to_h { |business_id, pairs| [ businesses.fetch(business_id), pairs.map(&:last) ] }
    end
end
