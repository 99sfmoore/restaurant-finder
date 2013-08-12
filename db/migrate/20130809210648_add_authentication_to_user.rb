class AddAuthenticationToUser < ActiveRecord::Migration
  def change
    add_column :users, :email, :string 
    add_column :users, :salt, :string
    add_column :users, :passwordhash, :string
  end
end
