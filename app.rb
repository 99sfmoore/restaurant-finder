require 'bundler/setup'

require 'sinatra'
require 'sinatra/activerecord'
require './setup.rb'
require 'sinatra/flash'
require 'sinatra/redirect_with_flash'
require 'pry-nav'  #use with binding.pry at debugging point
require 'bcrypt'


enable :sessions 


#this whole thing is weird
before do
 @cuisine_list = Cuisine.order(:name)
 @area_list = Restaurant.all.map{|r| r.area}.compact.uniq.sort
 @user = User.find_by(email: session[:email])
 @public_sources = Source.joins(:base_source).where(base_sources: {public_source: true})
 @personal_sources = @user.base_source.sources if @user
 @source_list = @public_sources + (@personal_sources || [])
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
    @title = "Restaurant List"
    @sources = Source.all #do I need this??
    @bases = BaseSource.all  #do I need this??
    erb :home
  else
    erb :login
  end
end

post '/signup' do
  if params[:password] != params[:confirm]
    redirect "/" #add message
  else
    password_salt = BCrypt::Engine.generate_salt
    password_hash = BCrypt::Engine.hash_secret(params[:password], password_salt)
    User.create(  name: params[:name],
                  email: params[:email],
                  salt: password_salt,
                  passwordhash: password_hash,
                  base_source: BaseSource.create(name: params[:email])
                  )
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
    redirect "/"
  end
  erb :error
end

get '/logout' do 
  session[:email] = nil
  redirect '/'
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
  @restaurant_list = Restaurant.where("name = ?", @search_string)
  if @restaurant_list.size == 1
    redirect "/rest_page/#{@restaurant_list.first.slug}"
  else
    @restaurant_list = Restaurant.where("name like ?","%#{@search_string}%")
  end
  @headers = ["Name","Cuisine","Neighborhood","Lists","Notes"]
  erb :list
end

get '/entry' do
  @title = "New Entry"
  @restaurant = Restaurant.new
  erb :create_entry
end

post '/entry' do
  if params[:source][:id] == "New List"
    @source = Source.create(name: params[:new_source_name])
      @source.slug = "#{@source.name}-#{@user.id}".to_url
      @user.base_source.sources << @source
      @user.save
  else 
    @source = Source.find_by(params[:source])
  end
  @restaurant_list = []
  params[:restaurant].values.each do |name|
    if name != ""
      @restaurant = Restaurant.find_by(name: name)
      unless @restaurant
        @restaurant = Restaurant.create(name: name)
        @restaurant.menulink = menulink(@restaurant.name)
        @restaurant.fill
      end
      @restaurant.sources << @source if @source
      @restaurant.save
      @restaurant_list << @restaurant
    end
  end
  erb :check_entry
end
  #if @restaurant.save
  #  redirect "/source/#{@source.name}", :notice => "Restaurant Added"
  #else
  #  redirect "/entry", :error => "Something went wrong"
  #end


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
  if params[:new_location] == "on"
    @restaurant = Restaurant.create(params[:restaurant])
    @restaurant.slug = @restaurant.menulink.match(/restaurants\/(.*)\/menu/)[1]
  else
    @restaurant = Restaurant.find_by(slug: params[:rest_name])
    @restaurant.update_attributes(params[:restaurant])
  end
  @restaurant.fill
  @restaurant.sources = Source.find(params[:sources].keys)
  @restaurant.save
  redirect "/rest_page/#{@restaurant.slug}"
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
  @title = "#{@user.name}'s History"
  erb :history
end




