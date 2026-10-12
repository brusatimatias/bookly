class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships do |t|
      # Covered by the (business_id, user_id) unique index below.
      t.references :business, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false

      t.timestamps

      t.check_constraint "role IN ('owner', 'admin', 'professional')", name: "memberships_role_valid"
    end

    # One role per person and business.
    add_index :memberships, %i[business_id user_id], unique: true
    # A single owner per business.
    add_index :memberships, :business_id, unique: true, where: "role = 'owner'", name: "index_memberships_on_business_id_one_owner"
  end
end
