class CreateNotesTable < ActiveRecord::Migration
  def change
    create_table :notes do |t|
      t.integer :restaurant_id
      t.integer :user_id
      t.string :content
    end
  end
end
