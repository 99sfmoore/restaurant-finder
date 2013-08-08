class Restaurant < ActiveRecord::Base
  has_and_belongs_to_many :sources
  has_and_belongs_to_many :cuisines
  #has_and_belongs_to_many :notes
  belongs_to :neighborhood
  has_many :visits

  def fill
    Restaurant.update(id, {:slug => name.to_url})
    if test_link(menulink)
      infopage = Nokogiri::HTML(open(menulink))
      nhood_info = get_neighborhood(infopage)
      area = Area.find_or_create_by(name: nhood_info[:area])
      neighborhood = Neighborhood.find_or_create_by(name: nhood_info[:neighborhood], area: area)
      Restaurant.update(id, { :address => get_address(infopage), 
                              :cross_street => get_cross_street(infopage),
                              :neighborhood => neighborhood })
      cuisines.concat(get_cuisine(infopage)).uniq! #is this correct?
    end
  end

  def get_neighborhood(infopage)
    area_info = infopage.xpath("//comment()").map { |comment| 
      comment.content.match(/"content.area\" content=\"(?<area>.*)\"/) ||
      comment.content.match(/"content.neighborhood" content="(?<hood>.*)"/)
    }.compact
    {area: area_info.first[:area].gsub("-"," ").titlecase, neighborhood: area_info.last[:hood].gsub("-"," ").titlecase}
  end

  def fill_neighborhood
    unless menulink.nil?
      infopage = Nokogiri::HTML(open(menulink))
      nhood_info = get_neighborhood(infopage)
      nhood = Neighborhood.find_by(name: nhood_info[:neighborhood])
      update_attribute(:neighborhood, nhood)
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

  def public?
    base_source.public_source
  end
end

class Cuisine < ActiveRecord::Base
  has_and_belongs_to_many :restaurants 
end

class Area < ActiveRecord::Base
  has_many :neighborhoods
end

class Neighborhood < ActiveRecord::Base
  has_many :restaurants
  belongs_to :area
end
