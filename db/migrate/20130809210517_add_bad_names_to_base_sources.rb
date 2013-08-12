class AddBadNamesToBaseSources < ActiveRecord::Migration
  def change
    add_column :base_sources, :bad_names, :text
  end
  
end
