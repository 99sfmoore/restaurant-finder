require './db_setup'
require 'nokogiri'
require 'net/http'
require 'open-uri'
require 'stringex'

MENU_PAGES_URL = "http://www.menupages.com"
def scrape(source)
  basesource = source.base_source
  
  case basesource.name

  when "Eater"
    eater_errors = ["Eater Maps","Top","Has Map","Eater 38"]
    page = Nokogiri::HTML(open(source.url))
    eater_page = page.css("div.block-anchor a")
    eater_names = eater_page.select {|item| item['href'].match("/tags/")}
    result = eater_names.map {|n| n.children.text.gsub(/\s{2,}/,"")}
    result.reject!{|name| eater_errors.include?(name)}
  when "Serious Eats"
    se_errors = ["Comment Policy page","report an inappropriate comment."]
    page = Nokogiri::HTML(open(source.url))
    se_page = page.css("p > a")
    result = se_page.map{|item| item.text}
    result.reject!{|name| se_errors.include?(name)}
  end
  result
end

def fill_from(source)
  name_list = scrape(source)
  name_list.each do |name|
    unless restaurant = Restaurant.find_by(name: name)
      infolink = menulink(name)
      if test_link(infolink)
        infopage = Nokogiri::HTML(open(infolink))
        nhood_info = get_neighborhood(infopage)
        restaurant = Restaurant.create( :name =>name,
                                        :slug =>name.to_url,
                                        :menulink => infolink, 
                                        :address => get_address(infopage), 
                                        :cross_street => get_cross_street(infopage),
                                        :area => nhood_info[:area],
                                        :neighborhood => nhood_info[:neighborhood])
        restaurant.cuisines.concat(get_cuisine(infopage))
      else 
        restaurant = Restaurant.create(:name => name, :slug => name.to_url)
      end
    end
    restaurant.sources << source
  end
end

def test_link(link)
  Net::HTTP.get_response(URI.parse(link)).code.to_i == 200
end

def menulink(name)
  "#{MENU_PAGES_URL}/restaurants/#{name.gsub(/[^a-zA-Z0-9 ]/,"").gsub(/\s/,"-")}/menu"
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

def get_neighborhood(infopage)
  area_info = infopage.xpath("//comment()").map { |comment| 
    comment.content.match(/"content.area\" content=\"(?<area>.*)\"/) ||
    comment.content.match(/"content.neighborhood" content="(?<hood>.*)"/)
  }.compact
  {area: area_info.first[:area].gsub("-"," ").titlecase, neighborhood: area_info.last[:hood].gsub("-"," ").titlecase}
end

def get_menu(menulink)
  menupage = Nokogiri::HTML(open(menulink))
  menupage.css("div#restaurant-menu")
end

#fill_from(my_source)

=begin
scrape(my_source).each do |name|
  puts name
  puts menulink(name)
end
=end

#name=\"content.tags\"
#doc.xpath("//meta[@name='Keywords']/@content").each do |attr|


=begin
mylist = eater_38
mylist.each do |name|
  unless name == "Has Map" || name == "Hot Hot Heat!"
    puts name
    infolink = menulink(name)
    puts infolink
    infopage = Nokogiri::HTML(open(infolink))
    puts get_address(infopage)
    puts get_cross_street(infopage)
    p get_cuisine(infopage)
    p get_neighborhood(infopage)
  end
   
end

@cuisines = Cuisine.order("name")
@cuisines.each {|c| 
  puts c.name
  c.name = c.name.lstrip
  puts c.name
  c.save }
=end

