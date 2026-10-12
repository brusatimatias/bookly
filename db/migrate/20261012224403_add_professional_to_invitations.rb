class AddProfessionalToInvitations < ActiveRecord::Migration[8.1]
  def change
    # Optional: links the invitation to an existing profile, which the new
    # member takes over on acceptance.
    add_column :invitations, :professional_id, :bigint

    # One pending invitation per profile.
    add_index :invitations, :professional_id, unique: true, where: "accepted_at IS NULL AND professional_id IS NOT NULL", name: "index_invitations_on_professional_id_pending"
    add_foreign_key :invitations, :professionals, column: %i[business_id professional_id], primary_key: %i[business_id id]
  end
end
