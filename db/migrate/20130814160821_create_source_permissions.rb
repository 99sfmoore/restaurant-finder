class CreateSourcePermissions < ActiveRecord::Migration
  def change
    create_table :permissions do |t|
      t.integer :user_id
      t.integer :source_id
      t.string  :status
      t.timestamps
    end
  end
end
