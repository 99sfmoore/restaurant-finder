class CreateUsersAndVisits < ActiveRecord::Migration
  def change
    create_table :visits do |t|
      t.date :date
      t.integer :restaurant_id
      t.string :notes
    end

    create_table :users do |t|
      t.string :name
      t.integer :base_source_id
    end

    create_join_table :users, :visits
  end
end
