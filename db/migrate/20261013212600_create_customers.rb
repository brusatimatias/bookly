class CreateCustomers < ActiveRecord::Migration[8.1]
  def change
    create_table :customers do |t|
      # Covered by the (business_id, id) unique index below.
      t.references :business, null: false, foreign_key: true, index: false
      # Normalized in the model (stripped and downcased).
      t.string :email, null: false
      t.string :name, null: false
      t.string :phone

      t.timestamps
    end

    # Target of composite foreign keys, so child rows can't mix businesses.
    add_index :customers, %i[business_id id], unique: true
    # Customers have no account: the email identifies them within a business.
    add_index :customers, %i[business_id email], unique: true
  end
end
