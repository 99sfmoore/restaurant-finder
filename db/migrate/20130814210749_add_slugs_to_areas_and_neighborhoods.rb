class AddSlugsToAreasAndNeighborhoods < ActiveRecord::Migration
  def change
    add_column :neighborhoods, :slug, :string
    add_column :areas, :slug, :string
  end
end
