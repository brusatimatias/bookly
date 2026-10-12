class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations do |t|
      t.references :business, null: false, foreign_key: true, index: false
      t.string :email, null: false
      t.string :role, null: false
      t.references :invited_by, null: false, foreign_key: { to_table: :users }
      t.datetime :expires_at, null: false
      t.datetime :accepted_at

      t.timestamps

      t.check_constraint "role IN ('admin', 'professional')", name: "invitations_role_valid"
    end

    # One pending invitation per email and business; accepted ones are kept as history.
    add_index :invitations, %i[business_id email], unique: true, where: "accepted_at IS NULL", name: "index_invitations_on_business_id_and_email_pending"
    add_index :invitations, :business_id
  end
end
