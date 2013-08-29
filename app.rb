require 'bundler/setup'

require 'sinatra'
require 'sinatra/activerecord'
require 'sinatra/flash'
require 'pry-nav'  
require 'bcrypt'
require 'stringex'
require 'json'

require './models'


enable :sessions 

set :database, "mysql2://root@localhost/restaurantproject2"

#this whole thing is weird

before do
  @title="Hungry?"
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
  @search_lists = { "Areas" => Area.order(:name),
                    "Cuisines" => Cuisine.order(:name),          
                    "Lists" => @user.sources #I'm not entirely sure how that brings in Public?
                    }
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

get '/load_source' do
  erb :load_source
end

#automatic loading of list from website
post '/load_source' do
  @base = BaseSource.find(params[:base_id])
  @source = Source.create(params[:source])
  @source.update_attributes(slug: @source.name.to_url)
  @base.sources << @source
  @restaurant_list = @source.fill.sort_by{|x| x.name}
  @headers = ["Name","Cuisine","Neighborhood","Delete"]
  erb :correct_source
end

#delete incorrectly loaded items #THIS NEEDS TO BE FIXED FOR NEW NON-SAVING CASE
post '/correct-source/:source' do
  @source = Source.find_by(slug: params[:source])
  @base_source = @source.base_source
  @rest_ids_to_delete = params.select{|k,v| v == "on"}.keys
  @errors = Restaurant.find(@rest_ids_to_delete).map{|r| r.name}
  @base_source.bad_names.concat(@errors)
  @base_source.save
  Restaurant.delete(@rest_ids_to_delete) #don't need to delete, because they were never made
  @restaurant_list = @source.restaurants
  @headers = ["Name","Cuisine","Neighborhood","New Menupages Link","New Link is for Different Location"]
  erb :check_entry
end

#allow user to enter own lists
get '/entry' do
  @allrest = Restaurant.array_of_names
  erb :create_entry
end

get '/create_list' do
  @allrest = Restaurant.array_of_names
  erb :create_new_list
end

#fill from user-generated list
post '/entry' do
  if params[:new_list]
    @source = Source.create(  name: params[:new_source_name],
                              description: params[:new_source_desc],
                              slug: "#{params[:new_source_name]}-#{@user.id}".to_url)
    Permission.create(user: @user, source: @source, status: "owned")
  else 
    @source = Source.find_by(params[:source])
  end
  name_list = params[:restaurant].values.reject{|x| x==""}
  @restaurant_list = Restaurant.initialize_from_list(name_list)
  @headers = ["Name","Cuisine","Neighborhood","New Menulink","Delete"]
  erb :check_entry
end

#updates menulinks to user-generated links
post '/correct-list' do
  binding.pry
  @source = Source.find(params[:source])
  @not_found = []
  params[:rest].each do |index, rest|
    restaurant = Restaurant.find_or_initialize_by(name: rest)
    if params[:links] && params[:links][index].size > 0
      restaurant = Restaurant.find_or_initialize_by( name: restaurant.name,
                                                      menulink: params[:links][index])
      restaurant.set_slug
      restaurant.fill
    end
    unless (params[:delete] && params[:delete][index])
      if restaurant.good_link
        restaurant.sources << @source if @source
      end
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
  if @restaurant.nil?
    erb :not_found
  else
    erb :rest_page
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
  if params[:delete] == "on"
    if restaurant.neighborhood
      flash[:message] = "#{restaurant.name} cannot be deleted"
    else
      flash[:message] = "#{restaurant.name} has been deleted"
      restaurant.destroy
    end
    redirect '/'
  else
    if params[:new_location] == "on"
      new_restaurant = Restaurant.create( name: restaurant.name,
                                          menulink: params[:restaurant][:menulink])
      new_restaurant.update_attributes(slug: new_restaurant.menulink.match(/restaurants\/(.*)\/menu/)[1])
      new_restaurant.fill
      restaurant = new_restaurant
    end
  restaurant.sources = (restaurant.sources.select{|s| @public_sources.include?(s)}||[]) + (params[:sources] ? Source.find(params[:sources].keys) : [])
  restaurant.save
  note = Note.find_or_create_by(restaurant: restaurant, user: @user)
  note.update_attributes(content: params[:notes])
  redirect "/rest_page/#{restaurant.slug}"
  end
end


get '/log-visit/:rest' do 
  @restaurant = Restaurant.find_by(slug: params[:rest])
  erb :log_visit
end

post '/log-visit' do
  @visit = Visit.create(params[:visit])
  @visit.update_attributes(user: @user)
  redirect "/user_history"
end

get '/log-mult-visits' do
  @lines = 10
  erb :log_multiple_visits
end

post '/log-mult-visits' do
  params[:lines].to_i.times do |n|
    n = n.to_s
    unless params[n][:restaurant] == ""
      restaurant = Restaurant.find_by(name: params[n][:restaurant])
      unless restaurant
        restaurant = Restaurant.create(name: params[n][:restaurant])
        restaurant.fill
      end
    Visit.create(restaurant: restaurant, date: params[n][:date], notes: params[n][:note], user: @user)
    end
  end
  flash[:add] = "Your visits have been added."
  redirect "/user_history"
end

get '/user_history' do
  erb :history
end

get '/edit-visit/:visit' do
  @visit = Visit.find(params[:visit])
  erb :edit_visit
end

post '/edit-visit/:id' do
  visit = Visit.find(params[:id])
  if params[:delete] == "on"
    flash[:edit] = "Visit to #{visit.restaurant.name} has been deleted"
    visit.destroy
  else
    visit.update_attributes(params[:visit])
    flash[:edit] = "Visit to #{visit.restaurant.name} has been updated"
  end
  redirect "/user_history"
end

get '/find-friends' do
  erb :find_friends
end

post '/find-friends' do
  @new_friends = []
    @not_found = []
  params[:email].values.reject{|x| x ==""}.each do |addr|
    friend = User.find_by(email: addr)
    if friend
      Friendship.create(user_id: @user.id, friend_id: friend.id, status: "false")
      @new_friends << friend
    else
      @not_found << addr
    end
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
  





