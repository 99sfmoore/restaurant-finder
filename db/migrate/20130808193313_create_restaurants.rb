class CreateRestaurants < ActiveRecord::Migration
  def change
    create_table :restaurants do |t|
      t.string :name
      t.string :slug
      t.string :menulink
      t.string :address
      t.string :cross_street
      t.string :area 
      t.string :neighborhood 
      t.string :notes

      t.timestamps
    end
  end
end