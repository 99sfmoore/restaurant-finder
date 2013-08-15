class DropUsersVisitsTable < ActiveRecord::Migration
  def change
    drop_table :users_visits
  end
end
