require 'sinatra'
require 'sinatra/activerecord'
require './setup.rb'
require 'sinatra/flash'
require 'sinatra/redirect_with_flash'
require 'pry-nav'  #use with binding.pry at debugging point



#set :database, "mysql:///restaurantproject.db"

#enable :sessions #what does this do?? DB???

configure do
 @@cuisine_list = Cuisine.order(:name)
 @@area_list = Restaurant.all.map{|r| r.area}.compact.uniq.sort
 @@source_list = Source.order(:name)
 @@user = User.find_by(name: "Sarah")
end


get '/' do
  @title = "Restaurant List"
  @sources = Source.all
  @bases = BaseSource.all
  @user = User.find_by(name: "Sarah") # fix this later
  erb :home
end

get '/all' do
  @title = "All Restaurants"
  @restaurant_list = Restaurant.order(:name)
  @headers = ["Name","Cuisine","Neighborhood","Other Lists","Notes"]
  erb :list
end

get '/source/new/:source' do
  @source = Source.find_by(:slug => params[:source])
  @restaurant_list = @source.restaurants.order(:name)
  @title = @source.name
  @headers = ["Name","Cuisine","Neighborhood","Other Lists","Notes","Delete"]
  erb :correct_source
end

post '/correct-source/:source' do
  @source = Source.find_by(slug: params[:source])
  @base_source = @source.base_source
  @rest_ids_to_delete = params.select{|k,v| v == "on"}.keys
  @errors = Restaurant.find(@rest_ids_to_delete).map{|r| r.name}
  @base_source.bad_names.concat(@errors)
  @base_source.save
  Restaurant.delete(@rest_ids_to_delete)
  redirect "/source/#{@source.slug}"
end


get '/source/:source' do
  @source = Source.find_by(:slug => params[:source])
  @restaurant_list = @source.restaurants.order(:name)
  @title = @source.name
  @headers = ["Name","Cuisine","Neighborhood","Other Lists","Notes"]
  erb :list
end

get '/cuisine/:cuisine' do
  @cuisine = Cuisine.find_by(slug: params[:cuisine])
  @restaurant_list = @cuisine.restaurants.order(:name)
  @title = @cuisine.name
  @headers = ["Name","Cuisine","Neighborhood","Lists","Notes"]
  erb :list
end

get '/neighborhood/:neighborhood' do
  @neighborhood_name = params[:neighborhood]
  #binding.pry
  @restaurant_list = Restaurant.where("neighborhood = ?", @neighborhood_name).order(:name)
  @title = @neighborhood_name
  @headers = ["Name","Cuisine","Lists","Notes"]
  @area = @restaurant_list.first.area
  erb :list
end

get '/area/:area' do
  @area_name = params[:area]
  @restaurant_list = Restaurant.where("area = ?", @area_name)
  @title = @area_name
  @headers = ["Name","Cuisine","Neighborhood","Lists","Notes"]
  erb :list
end

post '/load_source' do
  @base = BaseSource.find(params[:base_id])
  @source = Source.create(params[:source])
  @source.slug = @source.name.to_url
  @source.save # do I need this?
  @base.sources << @source
  fill_from(@source) 
  redirect "/source/new/#{@source.slug}"
end

get '/rest_page/:rest_name' do
  @slug = params[:rest_name]
  @restaurant = Restaurant.find_by(slug: @slug)
  if @restaurant
    @title = @restaurant.name
    @menu = get_menu(@restaurant.menulink)
    erb :rest_page
  else
    erb :not_found
  end
end

get '/rest_page' do 
  @search_string = params[:rest_name]
  @restaurant_list = Restaurant.where(name: @search_string)
  if @restaurant_list.size == 1
    redirect "/rest_page/#{@search_string.to_url}"
  else
    @headers = ["Name","Cuisine","Neighborhood","Lists","Notes"]
    erb :list
  end
end

get '/entry' do
  @title = "New Entry"
  @restaurant = Restaurant.new
  @user = User.find_by(name: "Sarah") #fix this
  erb :create_entry
end

post '/entry/:user_id' do
  @restaurant = Restaurant.find_by(params[:restaurant])
  unless @restaurant
    @restaurant = Restaurant.create(params[:restaurant])
    @restaurant.menulink = menulink(@restaurant.name)
    @restaurant.fill
  end
  @user = User.find(params[:user_id])
  if params[:source][:name] == "New List"
    @source = Source.create(params[:new_source])
    @source.slug = @source.name.to_url
    @user.base_source.sources << @source
    @user.save
  else
    @source = Source.find_by(params[:source])
  end
  @restaurant.sources << @source
  @restaurant.save
  redirect to "/source/#{@source.slug}"
  #if @restaurant.save
  #  redirect "/source/#{@source.name}", :notice => "Restaurant Added"
  #else
  #  redirect "/entry", :error => "Something went wrong"
  #end
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
  redirect "/" #/source/#{@source.slug}"
end

get '/edit/:rest_name' do
  @restaurant = Restaurant.find_by(slug: params[:rest_name])
  erb :edit
end  

post '/edit/:rest_name' do
  binding.pry
  if params[:new_location] == "on"
    @restaurant = Restaurant.create(params[:restaurant])
    @restaurant.slug = @restaurant.menulink.match(/restaurants\/(.*)\/menu/)[1]
    @restaurant.fill
    @restaurant.sources = Source.find(params[:sources].keys)
  else
    @restaurant = Restaurant.find_by(slug: params[:rest_name])
    if params[:restaurant][:name] != @restaurant.name #look if restaurant is already in database
      @duplicate_restaurant = Restaurant.find_by(name: params[:restaurant][:name])
      if @duplicate_restaurant #if it is, just add sources
        @duplicate_restaurant.sources.concat(@restaurant.sources)
        @duplicate_restaurant.sources.uniq!
        @restaurant.destroy
        @restaurant = @duplicate_restaurant
      end
    else
      @restaurant.update_attributes(params[:restaurant])
      @restaurant.fill
      @restaurant.sources = Source.find(params[:sources].keys)
    end
  end
  @restaurant.save
  redirect "/rest_page/#{@restaurant.slug}"
end

get '/log-visit/:rest' do #not using this yet
  @user = User.find_by(name: "Sarah") #fix this
  @restaurant = Restaurant.find_by(slug: params[:rest])
  erb :log_visit
end

post '/log-visit' do
  @user = User.find(params[:user])
  @visit = Visit.create(params[:visit])
  @user.visits << @visit
  redirect "/user_history/#{@user.id}"
end

get '/user_history/:user' do
  @user = User.find(params[:user])
  @history = @user.visits
  @title = "#{@user.name}'s History"
  erb :history
end




