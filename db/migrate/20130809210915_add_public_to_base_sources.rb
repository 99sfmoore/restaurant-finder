class AddPublicToBaseSources < ActiveRecord::Migration
  def change
    add_column :base_sources, :public_source, :boolean
  end
end
