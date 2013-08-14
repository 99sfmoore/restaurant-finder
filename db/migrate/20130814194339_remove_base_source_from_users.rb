class RemoveBaseSourceFromUsers < ActiveRecord::Migration
  def change
    remove_column :users, :base_source_id
  end
end
