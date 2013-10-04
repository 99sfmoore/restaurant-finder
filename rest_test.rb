require 'nokogiri'
require 'open-uri'

EATER_URL = "http://ny.eater.com/"
EATER_38_URL = "#{EATER_URL}archives/2013/04/new_yorks_38_essential_restaurants_april_13.php"
MENU_PAGES_URL = "http://www.menupages.com"

def eater
page = Nokogiri::HTML(open(EATER_38_URL))
eater_38 = page.css("div.block-anchor a")
eater_38_names = eater_38.select {|item| item['href'].match("/tags/")}
eater_38_names.map! {|n| n.children.text.gsub(/\s{2,}/,"")}
eater_38_names.each do |rest|
  menu_url = "#{MENU_PAGES_URL}/restaurants/#{rest.gsub(/\s/,"-")}/menu"
  puts rest+"\t\t"+menu_url
  puts
  page = Nokogiri::HTML(open(menu_url))
  menu = page.css("div#restaurant-menu")
  p menu
end
end

page = Nokogiri::HTML(open("http://newyork.seriouseats.com/2013/01/bill-telepan-neighborhood-guide-where-to-eat-upper-west-side.html"))
se_page = page.css("p > a")
se_names = se_page.map{|item| item.text}
p se_names




=begin
eater_38.children.each do |thing|
  p thing.children.children.children
  puts "This thing has #{thing.children.size} children\n\n\n"
end
puts "There are #{eater_38.children.size} children"
=end

=begin
<div class="name fn org overflow-controlled" title="Nom Wah Tea Parlor">
      
        Nom Wah Tea Parlor
      
    </div>
=end