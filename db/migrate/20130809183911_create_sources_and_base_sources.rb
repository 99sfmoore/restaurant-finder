class CreateSourcesAndBaseSources < ActiveRecord::Migration
  def change
    ActiveRecord::Migration.create_table :base_sources do |t|
      t.string :name
      t.string :base_url
    end

    ActiveRecord::Migration.create_table :sources do |t|
      t.integer :base_source_id
      t.string :name
      t.string :slug
      t.string :url
    end

    ActiveRecord::Migration.create_join_table :restaurants, :sources
  end
end
