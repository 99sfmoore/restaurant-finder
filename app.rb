require 'bundler/setup'

require 'sinatra'
require 'sinatra/activerecord'
require 'sinatra/flash'
require 'pry-nav'  
require 'bcrypt'
require 'stringex'

require './models'


enable :sessions 

set :database, "mysql2://root@localhost/restaurantproject2"

#this whole thing is weird

before do
  @title="TBD"
  @user = User.find_by(email: session[:email])
  @public_sources = Source.joins(:base_source).where(base_sources: {public_source: true})
  @list_generator = nil
end

helpers do

  def login?  #not currently using
    !session[:email].nil?
  end

  def username #not currently using
    session[:email]
  end
end
     


get '/' do
  if @user
    @bases = BaseSource.all  
    @friend_requests = @user.inverse_friendships.where("status = ?","false")
    erb :home
  else
    erb :login
  end
end

post '/signup' do
  if params[:password] != params[:confirm]
    flash[:password_error] = "Passwords must match"
    redirect "/" #add message
  elsif User.find_by(email: params[:email])
    flash[:user_error] = "An account already exists for this e-mail address"
  else
    password_salt = BCrypt::Engine.generate_salt
    password_hash = BCrypt::Engine.hash_secret(params[:password], password_salt)
    User.create(  name: params[:name],
                  email: params[:email],
                  salt: password_salt,
                  passwordhash: password_hash)
    session[:email] = params[:email]
  end
  redirect '/'
end

get '/login' do
  erb :login
end

post '/login' do
  @user = User.find_by(email: params[:email])
  if @user && @user.passwordhash == BCrypt::Engine.hash_secret(params[:password],@user.salt)
    session[:email] = params[:email]
  else
    flash[:login_error] = "Incorrect username and password"
  end
  redirect '/'
end

get '/logout' do 
  session[:email] = nil
  redirect '/'
end

#this is broken, need to rethink implementation
get '/all' do
  @restaurant_list = Restaurant.order(:name)
  @heading = "All Restaurants"
  @headers = ["Name","Cuisine","Neighborhood","Other Lists","Notes"]
  erb :list
end

get '/list_by/:type/:slug' do
  type = Module.const_get(params[:type].capitalize)
  @list_generator = type.find_by(slug: params[:slug])
  @heading = @list_generator.name
  @restaurant_list = @list_generator.restaurants
  case params[:type]
  when "neighborhood"
    @headers = ["Name","Cuisine","Lists","Notes"]
  when "source"
    @headers = ["Name","Cuisine","Neighborhood","Other Lists","Notes"]
  else
    @headers = ["Name","Cuisine","Neighborhood","Lists","Notes"]
  end
  erb :list
end

get '/custom' do
  @search_lists = { "Lists" => @user.sources, #I'm not entirely sure how that brings in Public?
                    "Cuisines" => Cuisine.order(:name),
                    "Areas" => Area.order(:name)}
  erb :custom
end

post '/custom' do
  @restaurant_list = []

  if params["Lists"] 
    @sources = Source.find(params["Lists"].keys)
    @source_find = []
    @sources.each {|s| @source_find.concat(s.restaurants).uniq!}
  else
    @source_find = Restaurant.all
  end

  if params["Cuisines"] 
    @cuisines = Cuisine.find(params["Cuisines"].keys)
    @cuisine_find = []
    @cuisines.each {|c| @cuisine_find.concat(c.restaurants).uniq!}
  else
    @cuisine_find = @source_find
  end
  
  if params["Areas"] 
    @areas = Area.find(params["Areas"].keys)
    @area_find = []
    @areas.each do |a|
      a.neighborhoods.each do |n|
        @area_find.concat(n.restaurants).uniq!
      end
    end
  else
    @area_find = @cuisine_find
  end
  @restaurant_list = @source_find & @cuisine_find & @area_find  
  @headers = ["Name","Cuisine","Neighborhood","Lists","Notes"]
  erb :list
end

#automatic loading of list from website
post '/load_source' do
  @base = BaseSource.find(params[:base_id])
  @source = Source.create(params[:source])
  @source.slug = @source.name.to_url
  @source.save # do I need this?
  @base.sources << @source
  @source.fill_from(@source.scrape)
  @restaurant_list = @source.restaurants.order(:name)
  @headers = ["Name","Cuisine","Neighborhood","Other Lists","Notes","Delete"]
  erb :correct_source
end

#delete incorrectly loaded items
post '/correct-source/:source' do
  @source = Source.find_by(slug: params[:source])
  @base_source = @source.base_source
  @rest_ids_to_delete = params.select{|k,v| v == "on"}.keys
  @errors = Restaurant.find(@rest_ids_to_delete).map{|r| r.name}
  @base_source.bad_names.concat(@errors)
  @base_source.save
  Restaurant.delete(@rest_ids_to_delete)
  @restaurant_list = @source.restaurants
  @headers = ["Name","Cuisine","Neighborhood","New Menulink"]
  erb :check_entry
end

#allow user to enter own lists
get '/entry' do
  @restaurant = Restaurant.new
  erb :create_entry
end

#fill from user-generated list
post '/entry' do
  if params[:source][:id] == "New List"
    @source = Source.create(  name: params[:new_source_name],
                              description: params[:new_source_desc],
                              slug: "#{params[:new_source_name]}-#{@user.id}".to_url)
    Permission.create(user: @user, source: @source, status: "owned")
  else 
    @source = Source.find_by(params[:source])
  end
  name_list = params[:restaurant].values.reject{|x| x==""}
  @restaurant_list = @source.fill_from(name_list)
  @headers = ["Name","Cuisine","Neighborhood","New Menulink","Same Name, Different Location"]
  erb :check_entry
end

#updates menulinks to user-generated links
post '/correct-list' do
  @source = Source.find(params[:source])
  params[:links].each do |id,link|
    unless link == ""
      restaurant = Restaurant.find(id)
      if params[:new_loc].keys.include?(id)
        new_restaurant = Restaurant.find_or_create_by(name: restaurant.name,
                                                      menulink: link)
        new_restaurant.sources << @source
        restaurant = new_restaurant
      else
        restaurant = Restaurant.find(id)
        restaurant.update_attributes(menulink: link)
      end
      restaurant.fill
    end
  end
  redirect "/list_by/source/#{@source.slug}"
end

get '/edit-list/:source' do
  @source = Source.find(params[:source])
  erb :edit_list
end

post '/edit-list/:source' do 
  @source = Source.find(params[:source])
  @source.update_attributes(params[:change])
  if params[:delete]
    @source.restaurants.delete(Restaurant.find(params[:delete].keys))
  end
  redirect "/list_by/source/#{@source.slug}"
end

get '/rest_page/:rest_name' do
  @slug = params[:rest_name]
  @restaurant = Restaurant.find_by(slug: @slug)
  if @restaurant
    @menu = @restaurant.get_menu
    erb :rest_page
  else
    erb :not_found
  end
end

get '/rest_page' do 
  @search_string = params[:rest_name]
  @restaurant_list = Restaurant.where("name = ?", @search_string)
  if @restaurant_list.size == 1
    redirect "/rest_page/#{@restaurant_list.first.slug}"
  else
    @restaurant_list = Restaurant.where("name like ?","%#{@search_string}%")
  end
  @headers = ["Name","Cuisine","Neighborhood","Lists","Notes"]
  erb :list
end
 
get '/delete/:rest_name' do 
  @restaurant = Restaurant.find_by(slug: params[:rest_name])
  erb :delete
end

post '/delete/:rest_name' do #add source name back
  @restaurant = Restaurant.find_by(slug: params[:rest_name]) #need to deal with mult. locations
  if params[:choice] == "total_delete"
    @restaurant.destroy
  else
    @restaurant.sources.delete(params[:choice])
  end 
  redirect "/" #/list_by/source/#{@source.slug}"
end

get '/edit/:rest' do
  @restaurant = Restaurant.find_by(slug: params[:rest])
  erb :edit
end  

post '/edit/:rest' do
  restaurant = Restaurant.find_by(slug: params[:rest])
  if params[:new_location] == "on"
    new_restaurant = Restaurant.create( name: restaurant.name,
                                        menulink: params[:restaurant][:menulink])
    new_restaurant.update_attributes(slug: new_restaurant.menulink.match(/restaurants\/(.*)\/menu/)[1])
    new_restaurant.fill
    restaurant = new_restaurant
  end
  restaurant.sources = (restaurant.sources.select{|s| @public_sources.include?(s)}||[]) + (params[:sources] ? Source.find(params[:sources].keys) : [])
  note = Note.find_or_create_by(restaurant: restaurant, user: @user)
  note.update_attributes(content: params[:notes])
  restaurant.save #do I need this?
  redirect "/rest_page/#{restaurant.slug}"
end


get '/log-visit/:rest' do #not using this yet
  @restaurant = Restaurant.find_by(slug: params[:rest])
  erb :log_visit
end

post '/log-visit' do
  @visit = Visit.create(params[:visit])
  @user.visits << @visit
  redirect "/user_history"
end

get '/user_history' do
  @history = @user.visits
  erb :history
end

get '/find-friends' do
  erb :find_friends
end

post '/find-friends' do
  @friend_list = User.where(email: params[:email].values)
  @unfound = @friend_list.size != params[:email].values.size
  @friend_list.each do |friend|
    Friendship.create(user_id: @user.id, friend_id: friend.id, status: "false")    
  end
  erb :friends_found
end

post '/accept-friendship' do
  @friend_list = Friendship.find(params[:friendship].keys)
  @friend_list.each do |fship|
    fship.update_attributes(status: "mutual")
  end
  redirect '/'
end

get '/share-list/:source' do
  @source = Source.find(params[:source])
  erb :share_list
end

post '/share-list/:source' do
  @source = Source.find(params[:source])
  params[:friends].each do |friend, status|
    p = Permission.find_or_create_by(user_id: friend, source: @source)
    if status == "none"
      p.destroy
    else
      p.update_attributes(status: status)
    end
  end
  redirect "/list_by/source/#{@source.slug}"
end
  





