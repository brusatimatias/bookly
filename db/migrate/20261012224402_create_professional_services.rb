class CreateProfessionalServices < ActiveRecord::Migration[8.1]
  def change
    create_table :professional_services do |t|
      t.references :business, null: false, foreign_key: true, index: false
      t.bigint :professional_id, null: false
      t.bigint :service_id, null: false

      t.timestamps
    end

    add_index :professional_services, %i[professional_id service_id], unique: true
    add_index :professional_services, %i[business_id service_id]
    add_foreign_key :professional_services, :professionals, column: %i[business_id professional_id], primary_key: %i[business_id id]
    add_foreign_key :professional_services, :services, column: %i[business_id service_id], primary_key: %i[business_id id]
  end
end
