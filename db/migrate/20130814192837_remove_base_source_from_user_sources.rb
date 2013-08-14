class RemoveBaseSourceFromUserSources < ActiveRecord::Migration
  def change
    remove_column :sources, :base_source_id
  end
end
