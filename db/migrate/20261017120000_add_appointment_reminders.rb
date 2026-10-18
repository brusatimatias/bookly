class AddAppointmentReminders < ActiveRecord::Migration[8.1]
  def change
    # How long before a confirmed appointment the customer gets a reminder; 0
    # turns reminders off.
    add_column :businesses, :reminder_hours_before, :integer, default: 24, null: false
    add_check_constraint :businesses, "reminder_hours_before >= 0", name: "businesses_reminder_hours_before_non_negative"

    # What SendRemindersJob scans: confirmed appointments without a reminder
    # (appointments.reminder_sent_at, set when it's sent).
    add_index :appointments, :starts_at, where: "status = 'confirmed' AND reminder_sent_at IS NULL", name: "index_appointments_awaiting_reminder"
  end
end
