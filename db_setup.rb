require 'active_record'
require 'mysql2'
require 'stringex'
require 'pry-nav'

ActiveRecord::Base.establish_connection(
  :adapter => "mysql2",
  :host => "localhost",
  :username => "root",
  #:password => "password",
  :database => "restaurantproject"
  )

class Restaurant < ActiveRecord::Base
  has_and_belongs_to_many :sources
  has_and_belongs_to_many :cuisines
  #has_and_belongs_to_many :notes
  has_many :visits

  def fill
    Restaurant.update(id, {:slug => name.to_url})
    if test_link(menulink)
      infopage = Nokogiri::HTML(open(menulink))
      nhood_info = get_neighborhood(infopage)
      Restaurant.update(id, { :address => get_address(infopage), 
                              :cross_street => get_cross_street(infopage),
                              :area => nhood_info[:area],
                              :neighborhood => nhood_info[:neighborhood] })
      cuisines.concat(get_cuisine(infopage)) #is this correct?
    end
  end
end

class User < ActiveRecord::Base
  has_and_belongs_to_many :visits
  belongs_to :base_source
  #has_and_belongs_to_many :notes
end

class Visit < ActiveRecord::Base
  belongs_to :restaurant
  has_and_belongs_to_many :users
  #has_and_belongs_to_many :notes
end

class BaseSource < ActiveRecord::Base
  has_many :sources
  serialize :bad_names, Array
end

class Source < ActiveRecord::Base
  belongs_to :base_source
  has_and_belongs_to_many :restaurants
  has_one :note
end

class Cuisine < ActiveRecord::Base
  has_and_belongs_to_many :restaurants 
end


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
    add_column :base_sources, :bad_names, :text
  end

  def down
    remove_column :base_sources, :bad_names
  end
end



@base = BaseSource.find_by(name: "Serious Eats")
@base.bad_names = ["Comment Policy page","report an inappropriate comment."]
p @base.bad_names
@base.save

=begin
@bases = BaseSource.all
binding.pry
@bases.each do |b|

  if b.name == "Eater"
    b.bad_names.concat(["Eater Maps","Top","Has Map","Eater 38"])
  elsif b.name == "Serious Eats"
    b.bad_names.concat(["Comment Policy page","report an inappropriate comment."])
  end
end
=end



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

