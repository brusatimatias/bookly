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

ActiveRecord::Schema[8.1].define(version: 2026_10_13_212601) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gist"
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "appointments", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.bigint "service_id", null: false
    t.bigint "professional_id", null: false
    t.bigint "customer_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.datetime "buffer_ends_at", null: false
    t.integer "price_cents", null: false
    t.integer "buffer_minutes", null: false
    t.datetime "request_expires_at"
    t.boolean "any_professional", default: false, null: false
    t.text "customer_notes"
    t.datetime "reminder_sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "customer_id"], name: "index_appointments_on_business_id_and_customer_id"
    t.index ["business_id", "id"], name: "index_appointments_on_business_id_and_id", unique: true
    t.index ["business_id", "service_id"], name: "index_appointments_on_business_id_and_service_id"
    t.index ["business_id", "starts_at"], name: "index_appointments_on_business_id_and_starts_at"
    t.index ["professional_id", "starts_at"], name: "index_appointments_on_professional_id_and_starts_at"
    t.index ["request_expires_at"], name: "index_appointments_on_request_expires_at_pending", where: "((status)::text = 'pending'::text)"
    t.check_constraint "buffer_ends_at >= ends_at", name: "appointments_buffer_after_end"
    t.check_constraint "buffer_minutes >= 0", name: "appointments_buffer_non_negative"
    t.check_constraint "ends_at > starts_at", name: "appointments_end_after_start"
    t.check_constraint "price_cents >= 0", name: "appointments_price_non_negative"
    t.check_constraint "status::text <> 'pending'::text OR request_expires_at IS NOT NULL", name: "appointments_pending_expires"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'confirmed'::character varying, 'rejected'::character varying, 'expired'::character varying, 'cancelled'::character varying, 'attended'::character varying, 'no_show'::character varying]::text[])", name: "appointments_status_valid"
    t.exclusion_constraint "professional_id WITH =, tsrange(starts_at, buffer_ends_at) WITH &&", where: "(status)::text = ANY ((ARRAY['pending'::character varying, 'confirmed'::character varying])::text[])", using: :gist, name: "appointments_no_double_booking"
  end

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
    t.check_constraint "locale::text = ANY (ARRAY['es'::character varying::text, 'en'::character varying::text])", name: "businesses_locale_valid"
    t.check_constraint "min_booking_notice_hours >= 0", name: "businesses_min_booking_notice_non_negative"
    t.check_constraint "request_expiration_hours > 0", name: "businesses_request_expiration_positive"
    t.check_constraint "slot_interval_minutes > 0", name: "businesses_slot_interval_positive"
    t.check_constraint "slug::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text", name: "businesses_slug_format"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'suspended'::character varying::text])", name: "businesses_status_valid"
  end

  create_table "customers", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "email"], name: "index_customers_on_business_id_and_email", unique: true
    t.index ["business_id", "id"], name: "index_customers_on_business_id_and_id", unique: true
  end

  create_table "invitations", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.string "email", null: false
    t.string "role", null: false
    t.bigint "invited_by_id", null: false
    t.datetime "expires_at", null: false
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "professional_id"
    t.index ["business_id", "email"], name: "index_invitations_on_business_id_and_email_pending", unique: true, where: "(accepted_at IS NULL)"
    t.index ["business_id"], name: "index_invitations_on_business_id"
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
    t.index ["professional_id"], name: "index_invitations_on_professional_id_pending", unique: true, where: "((accepted_at IS NULL) AND (professional_id IS NOT NULL))"
    t.check_constraint "role::text = ANY (ARRAY['admin'::character varying::text, 'professional'::character varying::text])", name: "invitations_role_valid"
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.bigint "user_id", null: false
    t.string "role", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "user_id"], name: "index_memberships_on_business_id_and_user_id", unique: true
    t.index ["business_id"], name: "index_memberships_on_business_id_one_owner", unique: true, where: "((role)::text = 'owner'::text)"
    t.index ["user_id"], name: "index_memberships_on_user_id"
    t.check_constraint "role::text = ANY (ARRAY['owner'::character varying::text, 'admin'::character varying::text, 'professional'::character varying::text])", name: "memberships_role_valid"
  end

  create_table "professional_services", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.bigint "professional_id", null: false
    t.bigint "service_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "service_id"], name: "index_professional_services_on_business_id_and_service_id"
    t.index ["professional_id", "service_id"], name: "index_professional_services_on_professional_id_and_service_id", unique: true
  end

  create_table "professionals", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.bigint "user_id"
    t.string "name", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "id"], name: "index_professionals_on_business_id_and_id", unique: true
    t.index ["business_id", "user_id"], name: "index_professionals_on_business_id_and_user_id", unique: true, where: "(user_id IS NOT NULL)"
  end

  create_table "services", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.string "name", null: false
    t.integer "duration_minutes", null: false
    t.integer "price_cents", default: 0, null: false
    t.integer "buffer_minutes"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "business_id, lower((name)::text)", name: "index_services_on_business_id_and_lower_name", unique: true
    t.index ["business_id", "id"], name: "index_services_on_business_id_and_id", unique: true
    t.check_constraint "buffer_minutes >= 0", name: "services_buffer_non_negative"
    t.check_constraint "duration_minutes > 0", name: "services_duration_positive"
    t.check_constraint "price_cents >= 0", name: "services_price_non_negative"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "time_blocks", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.bigint "professional_id", null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.string "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "professional_id", "starts_at"], name: "index_time_blocks_on_professional_and_starts_at"
    t.check_constraint "ends_at > starts_at", name: "time_blocks_end_after_start"
    t.exclusion_constraint "professional_id WITH =, tsrange(starts_at, ends_at) WITH &&", using: :gist, name: "time_blocks_no_overlap"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.boolean "platform_admin", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "working_hours", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.bigint "professional_id", null: false
    t.integer "day_of_week", limit: 2, null: false
    t.time "start_time", null: false
    t.time "end_time", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "professional_id"], name: "index_working_hours_on_business_id_and_professional_id"
    t.check_constraint "day_of_week >= 0 AND day_of_week <= 6", name: "working_hours_day_of_week_valid"
    t.check_constraint "end_time > start_time", name: "working_hours_end_after_start"
    t.exclusion_constraint "professional_id WITH =, day_of_week WITH =, tsrange(('2000-01-01'::date + start_time), ('2000-01-01'::date + end_time)) WITH &&", using: :gist, name: "working_hours_no_overlap"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "appointments", "businesses"
  add_foreign_key "appointments", "customers", column: ["business_id", "customer_id"], primary_key: ["business_id", "id"]
  add_foreign_key "appointments", "professionals", column: ["business_id", "professional_id"], primary_key: ["business_id", "id"]
  add_foreign_key "appointments", "services", column: ["business_id", "service_id"], primary_key: ["business_id", "id"]
  add_foreign_key "customers", "businesses"
  add_foreign_key "invitations", "businesses"
  add_foreign_key "invitations", "professionals", column: ["business_id", "professional_id"], primary_key: ["business_id", "id"]
  add_foreign_key "invitations", "users", column: "invited_by_id"
  add_foreign_key "memberships", "businesses"
  add_foreign_key "memberships", "users"
  add_foreign_key "professional_services", "businesses"
  add_foreign_key "professional_services", "professionals", column: ["business_id", "professional_id"], primary_key: ["business_id", "id"]
  add_foreign_key "professional_services", "services", column: ["business_id", "service_id"], primary_key: ["business_id", "id"]
  add_foreign_key "professionals", "businesses"
  add_foreign_key "professionals", "memberships", column: ["business_id", "user_id"], primary_key: ["business_id", "user_id"]
  add_foreign_key "services", "businesses"
  add_foreign_key "sessions", "users"
  add_foreign_key "time_blocks", "businesses"
  add_foreign_key "time_blocks", "professionals", column: ["business_id", "professional_id"], primary_key: ["business_id", "id"]
  add_foreign_key "working_hours", "businesses"
  add_foreign_key "working_hours", "professionals", column: ["business_id", "professional_id"], primary_key: ["business_id", "id"]
end
