require 'nokogiri'
require 'net/http'
require 'open-uri'
require 'stringex'

MENU_PAGES_URL = "http://www.menupages.com"

class Restaurant < ActiveRecord::Base
  validates :menulink, uniqueness: true
  validates :neighborhood, presence: true
  has_and_belongs_to_many :sources #conditions: {uniq: true}
  has_and_belongs_to_many :cuisines #conditions: {uniq: true}
  has_many :notes
  belongs_to :neighborhood
  has_one :area, through: :neighborhood
  has_many :visits, dependent: :destroy

  def self.initialize_from_list(names)
    names.map do |name|
      new_rest = Restaurant.find_or_initialize_by(name: name)
      new_rest.fill
    end
  end

  def self.array_of_names
    self.pluck(:name).map{|n| n.gsub("'","&#x27;")}
  end

  def fill
    unless menulink
      self.attributes={slug: name.to_url, menulink: get_menulink}
    end
    if good_link && area.nil?
      infopage = Nokogiri::HTML(open(menulink))
      nhood_info = get_neighborhood(infopage)
      area = Area.find_or_create_by(name: nhood_info[:area])
      neighborhood = Neighborhood.find_or_create_by(name: nhood_info[:neighborhood], area: area)
      self.attributes={  address: get_address(infopage), 
                    cross_street: get_cross_street(infopage),
                    neighborhood: neighborhood }
      cuisines.concat(get_cuisine(infopage))
      self.save
    end
    self
  end

  def get_neighborhood(infopage)
    area_info = infopage.xpath("//comment()").map { |comment| 
      comment.content.match(/"content.area\" content=\"(?<area>.*)\"/) ||
      comment.content.match(/"content.neighborhood" content="(?<hood>.*)"/)
    }.compact
    {area: area_info.first[:area].gsub("-"," ").titlecase, neighborhood: area_info.last[:hood].gsub("-"," ").titlecase}
  end

  def good_link
    (menulink =~ /www\./) && Net::HTTP.get_response(URI.parse(menulink)).code.to_i == 200
  end

  def get_address(infopage)
    infopage.css("li.address.adr").css("span.addr.street-address").text
  end

  def get_cross_street(infopage)
    infopage.css("li.cross-street").text
  end

  def get_cuisine(infopage)
    infopage.css("li.cuisine.category").text.split(", ").map do |cname|
      Cuisine.find_or_create_by(name: cname, slug: cname.to_url)
    end
  end

  def get_menulink
    "#{MENU_PAGES_URL}/restaurants/#{name.gsub(/[^a-zA-Z0-9 ]/,"").gsub(/\s/,"-")}/menu"
  end

  def set_slug
    slug = menulink.match(/restaurants\/(.*)\/menu/)[1]
  end

  def get_menu
    menupage = Nokogiri::HTML(open(menulink).read)
    menupage.encoding = 'utf-8'
    menupage.css("div#restaurant-menu")  #.delete(/<td>&nsbp<\/td>/) class is Nokogiri::XML::Nodeset
  end

  def display_note(user)
    found_note = self.notes.where("user_id = ?",user.id).first
    if found_note
      return found_note.content
    else
      return ""
    end
  end
end

class User < ActiveRecord::Base
  validates :email, uniqueness: true
  has_many :visits
  has_many :friendships
  has_many :friends, through: :friendships
  has_many :inverse_friendships, class_name: "Friendship", foreign_key: "friend_id"
  has_many :inverse_friends, through: :inverse_friendships, source: :user
  has_many :permissions
  has_many :sources, through: :permissions
  has_many :notes

  def friend_list
    self.friends.where("status = ?","mutual") + self.inverse_friends.where("status = ?","mutual")
  end

  def owned_lists
    self.sources.where("status = ?","owned")
  end

  def shared_lists
    self.sources.where("status = ?","shared")
  end

  def joint_lists
    self.sources.where("status = ?","joint")
  end

  def editable_lists
    owned_lists.concat(joint_lists)
  end

end

class Friendship < ActiveRecord::Base
  belongs_to :user
  belongs_to :friend, class_name: 'User'  
end

class Permission < ActiveRecord::Base
  belongs_to :user
  belongs_to :source
end

class Note < ActiveRecord::Base
  belongs_to :restaurant
  belongs_to :user
end

class Visit < ActiveRecord::Base
  belongs_to :restaurant
  belongs_to :user
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
  has_many :users, through: :permissions

  def public?
    base_source
  end

  def scrape
    basesource = self.base_source
    errors = basesource.bad_names
    
    case basesource.name

    when "Eater"
      page = Nokogiri::HTML(open(self.url))
      eater_page = page.css("div.block-anchor a")
      eater_names = eater_page.select {|item| item['href'].match("/tags/")}
      result = eater_names.map {|n| n.children.text.gsub(/\s{2,}/,"")}
      result.reject!{|name| errors.include?(name)}
    when "Serious Eats Neighborhood Guide"
      page = Nokogiri::HTML(open(self.url))
      se_page = page.css("p > a")
      result = se_page.map{|item| item.text}
      result.reject!{|name| errors.include?(name)}
    when "Serious Eats"
      page = Nokogiri::HTML(open(self.url))
      se_page = page.css("p > strong > a")
      result = se_page.map{|item| item.text}
      result.reject!{|name| errors.include?(name)}
    end
    result
  end


  def fill(name_list = nil) #see threaded, below THIS NEEDS TO BE REFACTORED!!!
    restaurant_list = []
    name_list = name_list || scrape
    name_list.each do |name|
      restaurant = Restaurant.find_or_initialize_by(name: name)
      restaurant.fill
      self.restaurants << restaurant
      restaurant_list << restaurant
    end
    restaurant_list #returns list of restaurants
  end
end

class Cuisine < ActiveRecord::Base
  has_and_belongs_to_many :restaurants 
end

class Area < ActiveRecord::Base
  has_many :neighborhoods
  has_many :restaurants, through: :neighborhoods
end

class Neighborhood < ActiveRecord::Base
  has_many :restaurants
  belongs_to :area
end
