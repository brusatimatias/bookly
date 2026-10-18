# Expires the requests nobody answered in time, in every business. Runs every
# minute (config/recurring.yml); each request expires within its own business.
class ExpireRequestsJob < ApplicationJob
  queue_as :default

  def perform
    overdue_by_business.each do |business, appointment_ids|
      Current.set(business: business) do
        Appointment.where(id: appointment_ids).find_each do |appointment|
          appointment.expire!
        rescue Appointment::InvalidTransition
          # Answered while the job ran.
        end
      end
    end
  end

  private
    # { business => [appointment id, ...] } for the pending requests whose
    # deadline passed.
    def overdue_by_business
      rows = BusinessScoped.across_businesses do
        Appointment.pending.where(request_expires_at: ..Time.current).pluck(:business_id, :id)
      end
      businesses = Business.where(id: rows.map(&:first)).index_by(&:id)

      rows.group_by(&:first).to_h { |business_id, pairs| [ businesses.fetch(business_id), pairs.map(&:last) ] }
    end
end
