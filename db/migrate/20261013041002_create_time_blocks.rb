class CreateTimeBlocks < ActiveRecord::Migration[8.1]
  def change
    create_table :time_blocks do |t|
      t.references :business, null: false, foreign_key: true, index: false
      t.bigint :professional_id, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :reason

      t.timestamps

      t.check_constraint "ends_at > starts_at", name: "time_blocks_end_after_start"
    end

    add_index :time_blocks, %i[business_id professional_id starts_at], name: "index_time_blocks_on_professional_and_starts_at"
    add_foreign_key :time_blocks, :professionals, column: %i[business_id professional_id], primary_key: %i[business_id id]
    # Blocks of the same professional can't overlap; they may touch.
    add_exclusion_constraint :time_blocks, "professional_id WITH =, tsrange(starts_at, ends_at) WITH &&",
      using: :gist, name: "time_blocks_no_overlap"
  end
end
