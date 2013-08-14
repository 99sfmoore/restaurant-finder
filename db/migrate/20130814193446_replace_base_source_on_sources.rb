class ReplaceBaseSourceOnSources < ActiveRecord::Migration
  def change
    add_column :sources, :base_source_id, :integer
  end
end
