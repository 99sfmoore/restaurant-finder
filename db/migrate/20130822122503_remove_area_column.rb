class RemoveAreaColumn < ActiveRecord::Migration
  def change
    remove_column :restaurants, :area  
  end
end
