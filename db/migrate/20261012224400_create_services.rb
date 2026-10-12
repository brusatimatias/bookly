class CreateServices < ActiveRecord::Migration[8.1]
  def change
    create_table :services do |t|
      # Covered by the (business_id, id) unique index below.
      t.references :business, null: false, foreign_key: true, index: false
      t.string :name, null: false
      t.integer :duration_minutes, null: false
      t.integer :price_cents, null: false, default: 0
      # NULL uses the business's buffer.
      t.integer :buffer_minutes
      t.boolean :active, null: false, default: true

      t.timestamps

      t.check_constraint "duration_minutes > 0", name: "services_duration_positive"
      t.check_constraint "price_cents >= 0", name: "services_price_non_negative"
      t.check_constraint "buffer_minutes >= 0", name: "services_buffer_non_negative"
    end

    # Target of composite foreign keys, so child rows can't mix businesses.
    add_index :services, %i[business_id id], unique: true
    add_index :services, "business_id, lower(name)", unique: true, name: "index_services_on_business_id_and_lower_name"
  end
end
