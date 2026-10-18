class CreateProfessionals < ActiveRecord::Migration[8.1]
  def change
    create_table :professionals do |t|
      # Covered by the (business_id, id) unique index below.
      t.references :business, null: false, foreign_key: true, index: false
      # Optional: a profile can exist before its person has an account.
      t.bigint :user_id
      t.string :name, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    # Target of composite foreign keys, so child rows can't mix businesses.
    add_index :professionals, %i[business_id id], unique: true
    # One profile per member.
    add_index :professionals, %i[business_id user_id], unique: true, where: "user_id IS NOT NULL"
    # The linked user must be a member of the same business.
    add_foreign_key :professionals, :memberships, column: %i[business_id user_id], primary_key: %i[business_id user_id]
  end
end
