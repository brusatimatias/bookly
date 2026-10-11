class CreateBusinesses < ActiveRecord::Migration[8.1]
  def change
    create_table :businesses do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :time_zone, null: false, default: "America/Argentina/Buenos_Aires"
      t.string :locale, null: false, default: "es"
      t.string :currency, null: false, default: "ARS"

      t.string :contact_email
      t.string :contact_phone
      t.string :address

      # Booking configuration
      t.integer :slot_interval_minutes, null: false, default: 30
      t.integer :buffer_minutes, null: false, default: 0
      t.integer :cancellation_window_hours, null: false, default: 24
      t.integer :request_expiration_hours, null: false, default: 24
      t.integer :min_booking_notice_hours, null: false, default: 2
      t.integer :booking_horizon_days, null: false, default: 60

      t.string :status, null: false, default: "active"
      t.datetime :suspended_at

      t.timestamps

      t.index :slug, unique: true

      t.check_constraint "slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'", name: "businesses_slug_format"
      t.check_constraint "locale IN ('es', 'en')", name: "businesses_locale_valid"
      t.check_constraint "status IN ('active', 'suspended')", name: "businesses_status_valid"
      t.check_constraint "slot_interval_minutes > 0", name: "businesses_slot_interval_positive"
      t.check_constraint "buffer_minutes >= 0", name: "businesses_buffer_non_negative"
      t.check_constraint "cancellation_window_hours >= 0", name: "businesses_cancellation_window_non_negative"
      t.check_constraint "request_expiration_hours > 0", name: "businesses_request_expiration_positive"
      t.check_constraint "min_booking_notice_hours >= 0", name: "businesses_min_booking_notice_non_negative"
      t.check_constraint "booking_horizon_days > 0", name: "businesses_booking_horizon_positive"
    end
  end
end
