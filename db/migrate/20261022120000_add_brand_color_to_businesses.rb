class AddBrandColorToBusinesses < ActiveRecord::Migration[8.1]
  def change
    # The color of the business's public pages and customer emails, as
    # #rrggbb in lowercase; none keeps Bookly's. The logo is an attachment.
    add_column :businesses, :brand_color, :string
    add_check_constraint :businesses, "brand_color ~ '^#[0-9a-f]{6}$'", name: "businesses_brand_color_format"
  end
end
