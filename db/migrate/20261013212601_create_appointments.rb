class CreateAppointments < ActiveRecord::Migration[8.1]
  STATUSES = %w[pending confirmed rejected expired cancelled attended no_show].freeze

  def change
    create_table :appointments do |t|
      t.references :business, null: false, foreign_key: true, index: false
      t.bigint :service_id, null: false
      t.bigint :professional_id, null: false
      t.bigint :customer_id, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      # ends_at plus the break after the service, computed in Rails
      # (timestamp + interval can't be a generated column).
      t.datetime :buffer_ends_at, null: false
      # Copied from the service, so later changes don't alter booked appointments.
      t.integer :price_cents, null: false
      t.integer :buffer_minutes, null: false
      t.datetime :request_expires_at
      # The customer picked "any professional".
      t.boolean :any_professional, null: false, default: false
      t.text :customer_notes
      t.datetime :reminder_sent_at

      t.timestamps

      t.check_constraint "status IN (#{STATUSES.map { |status| "'#{status}'" }.join(", ")})", name: "appointments_status_valid"
      t.check_constraint "ends_at > starts_at", name: "appointments_end_after_start"
      t.check_constraint "buffer_ends_at >= ends_at", name: "appointments_buffer_after_end"
      t.check_constraint "price_cents >= 0", name: "appointments_price_non_negative"
      t.check_constraint "buffer_minutes >= 0", name: "appointments_buffer_non_negative"
      t.check_constraint "status <> 'pending' OR request_expires_at IS NOT NULL", name: "appointments_pending_expires"
    end

    # Target of composite foreign keys (appointment events).
    add_index :appointments, %i[business_id id], unique: true
    add_index :appointments, %i[business_id starts_at]
    add_index :appointments, %i[professional_id starts_at]
    add_index :appointments, :request_expires_at, where: "status = 'pending'", name: "index_appointments_on_request_expires_at_pending"
    add_index :appointments, %i[business_id customer_id]
    add_index :appointments, %i[business_id service_id]

    add_foreign_key :appointments, :services, column: %i[business_id service_id], primary_key: %i[business_id id]
    add_foreign_key :appointments, :professionals, column: %i[business_id professional_id], primary_key: %i[business_id id]
    add_foreign_key :appointments, :customers, column: %i[business_id customer_id], primary_key: %i[business_id id]

    # No double booking: active appointments (pending ones already hold their
    # time) of the same professional can't overlap, break included.
    add_exclusion_constraint :appointments, "professional_id WITH =, tsrange(starts_at, buffer_ends_at) WITH &&",
      using: :gist, where: "status IN ('pending', 'confirmed')", name: "appointments_no_double_booking"
  end
end
