class RemoveNotesColumnFromRestaurants < ActiveRecord::Migration
  def change
    remove_column :restaurants, :notes, :string
  end
end
