require 'active_record'
require 'mysql2'
require 'stringex'
require 'pry-nav'
require 'bcrypt'

def make_database # I think I only have to do this once
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
=begin
  ActiveRecord::Migration.create_table :restaurants_sources, id: false do |t|
    t.integer :restaurant_id
    t.integer :base_source_id
  end
=end

  ActiveRecord::Migration.create_join_table :restaurants, :sources

  ActiveRecord::Migration.create_table :restaurants do |t|
    t.string :name
    t.string :slug
    t.string :menulink
    t.string :address
    t.string :cross_street
    t.string :area 
    t.string :neighborhood 
    t.string :notes
  end

  ActiveRecord::Migration.create_table :visits do |t|
    t.date :date
    t.integer :restaurant_id
    t.string :notes
  end

  ActiveRecord::Migration.create_table :users do |t|
    t.string :name
    t.integer :base_source_id
  end
=begin
  ActiveRecord::Migration.create_table :users_visits, id: false do |t|
    t.integer :user_id
    t.integer :visit_id
  end
=end

  ActiveRecord::Migration.create_join_table :users, :visits

  ActiveRecord::Migration.create_table :cuisines do |t|
    t.string :name
    t.string :slug
  end

=begin
  ActiveRecord::Migration.create_table :cuisines_restaurants, id: false do |t|
    t.integer :cuisine_id
    t.integer :restaurant_id
  end
=end
  ActiveRecord::Migration.create_join_table :cuisines, :restaurants

end


class AddErrorstoBase < ActiveRecord::Migration
  def up
    add_column :base_sources, :error, :text
  end
end

class MakeErrorPlural < ActiveRecord::Migration
  def up
    rename_column :base_sources, :error, :errors
  end
end


class DeleteErrorColumn < ActiveRecord::Migration
  def up
    remove_column :base_sources, :errors
  end
end


class AddBadNamesToBase < ActiveRecord::Migration
  def up
    add_column :base_sources, :bad_names, :text  #string or text??
  end

  def down
    remove_column :base_sources, :bad_names
  end
end

class AddAuthenticationToUser < ActiveRecord::Migration
  def up
    add_column :users, :email, :string  #string or text???
    add_column :users, :salt, :string
    add_column :users, :passwordhash, :string
  end

  def down
    remove_column :users, :email
    remove_column :users, :salt
    remove_column :users, :passwordhash
  end
end

class AddPublicToBaseSource < ActiveRecord::Migration
  def up
    add_column :base_sources, :public, :boolean
  end

  def down
    remove_column :base_sources, :public
  end
end

class RenamePublic < ActiveRecord::Migration
  def up
    rename_column :base_sources, :public, :public_source
  end
 end
 

=begin
  
class AddSlugs < ActiveRecord::Migration ## this is weird, figure out migrate
    def up
      add_column :cuisines, :slug, :string
      add_column :neighborhood, :slug, :string
    end
  end
=end

=begin
make_database
user = User.create(name: "Sarah")
user.base_source = BaseSource.create(name: "Sarah")
user.save
BaseSource.create(name: "Serious Eats", base_url: "http://newyork.seriouseats.com")
BaseSource.create(name: "Eater", base_url: "http://ny.eater.com")
=end



=begin
cuisines = Cuisine.all
cuisines.each do |c|
  c.slug = c.name.to_url
  c.save
end
=end

