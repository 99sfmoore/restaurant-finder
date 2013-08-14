class AddDescriptionToSources < ActiveRecord::Migration
  def change
    add_column :sources, :description, :string
  end
end
