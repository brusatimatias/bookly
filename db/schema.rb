# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_11_001906) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "businesses", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "time_zone", default: "America/Argentina/Buenos_Aires", null: false
    t.string "locale", default: "es", null: false
    t.string "currency", default: "ARS", null: false
    t.string "contact_email"
    t.string "contact_phone"
    t.string "address"
    t.integer "slot_interval_minutes", default: 30, null: false
    t.integer "buffer_minutes", default: 0, null: false
    t.integer "cancellation_window_hours", default: 24, null: false
    t.integer "request_expiration_hours", default: 24, null: false
    t.integer "min_booking_notice_hours", default: 2, null: false
    t.integer "booking_horizon_days", default: 60, null: false
    t.string "status", default: "active", null: false
    t.datetime "suspended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_businesses_on_slug", unique: true
    t.check_constraint "booking_horizon_days > 0", name: "businesses_booking_horizon_positive"
    t.check_constraint "buffer_minutes >= 0", name: "businesses_buffer_non_negative"
    t.check_constraint "cancellation_window_hours >= 0", name: "businesses_cancellation_window_non_negative"
    t.check_constraint "locale::text = ANY (ARRAY['es'::character varying, 'en'::character varying]::text[])", name: "businesses_locale_valid"
    t.check_constraint "min_booking_notice_hours >= 0", name: "businesses_min_booking_notice_non_negative"
    t.check_constraint "request_expiration_hours > 0", name: "businesses_request_expiration_positive"
    t.check_constraint "slot_interval_minutes > 0", name: "businesses_slot_interval_positive"
    t.check_constraint "slug::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text", name: "businesses_slug_format"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'suspended'::character varying]::text[])", name: "businesses_status_valid"
  end
end
