class CreateWorkingHours < ActiveRecord::Migration[8.1]
  def change
    create_table :working_hours do |t|
      t.references :business, null: false, foreign_key: true, index: false
      t.bigint :professional_id, null: false
      # 0 = Sunday, like Date#wday.
      t.integer :day_of_week, limit: 2, null: false
      # Local times in the business's time zone. A range doesn't cross midnight.
      t.time :start_time, null: false
      t.time :end_time, null: false

      t.timestamps

      t.check_constraint "day_of_week BETWEEN 0 AND 6", name: "working_hours_day_of_week_valid"
      t.check_constraint "end_time > start_time", name: "working_hours_end_after_start"
    end

    add_index :working_hours, %i[business_id professional_id]
    add_foreign_key :working_hours, :professionals, column: %i[business_id professional_id], primary_key: %i[business_id id]
    # Ranges of the same professional and day can't overlap; they may touch
    # (09:00-13:00 and 13:00-17:00). time has no range type, so the times are
    # put on a fixed date.
    add_exclusion_constraint :working_hours,
      "professional_id WITH =, day_of_week WITH =, tsrange(DATE '2000-01-01' + start_time, DATE '2000-01-01' + end_time) WITH &&",
      using: :gist, name: "working_hours_no_overlap"
  end
end
