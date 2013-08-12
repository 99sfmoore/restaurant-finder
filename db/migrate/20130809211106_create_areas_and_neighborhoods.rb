class CreateAreasAndNeighborhoods < ActiveRecord::Migration
  def change
    create_table :areas do |t|
      t.string :name
    end

    create_table :neighborhoods do |t|
      t.string :name
      t.integer :area_id
    end

    remove_column :restaurants, :neighborhood
    add_column :restaurants, :neighborhood_id, :integer
  end
end
  
