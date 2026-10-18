# Lets exclusion constraints combine equality on plain columns (professional,
# day) with range overlap.
class EnableBtreeGist < ActiveRecord::Migration[8.1]
  def change
    enable_extension "btree_gist"
  end
end
