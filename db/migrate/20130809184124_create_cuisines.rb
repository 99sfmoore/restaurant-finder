class CreateCuisines < ActiveRecord::Migration
  def change
    create_table :cuisines do |t|
      t.string :name
      t.string :slug
    end

    create_join_table :cuisines, :restaurants
  end
end
