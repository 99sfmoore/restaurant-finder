require 'sinatra'
require 'sinatra/activerecord'
require './setup.rb'
require 'sinatra/flash'
require 'sinatra/redirect_with_flash'
require 'pry-nav'  #use with binding.pry at debugging point



#set :database, "mysql:///restaurantproject.db"

#enable :sessions #what does this do?? DB???


get '/' do
  @title = "Restaurant List"
  @restaurant = Restaurant.new #not sure if I need this
  @sources = Source.all
  @bases = BaseSource.all
  @user = User.find_by(name: "Sarah") # fix this later
  erb :home
end

get '/source/:source_name' do
  @source = Source.find_by(:slug => params[:source_name])
  @title = @source.name
  erb :list
end

post '/load_source' do
  @base = BaseSource.find(params[:base_id])
  @source = Source.create(params[:source])
  @source.slug = @source.name.to_url
  @source.save # do I need this?
  @base.sources << @source
  fill_from(@source) #is there a better way to access the newly created source?
  redirect '/'
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

get '/rest_page' do #fixed by url -- I think!
  redirect "/rest_page/#{params[:rest_name].to_url}"
end

get '/menu/:name' do # I don't think I use this anymore
  @restaurant = Restaurant.find_by(name: params[:name])
  if @restaurant
    @title = @restaurant.name + " Menu"
    @menulink = @restaurant.menulink #this is also in db, could change
    @menu = get_menu(@restaurant.name)
    erb :menu
  else
    @name = params[:rest_name]
    erb :not_found
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
=begin    
  infolink = menulink(@restaurant.name)
  infopage = Nokogiri::HTML(open(infolink))
  @restaurant.menulink = menulink(infolink)
  @restaurant.address = get_address(infopage)
  @restaurant.cross_street = get_cross_street(infopage)
  nhood_info = get_neighborhood(infopage)
  @restaurant.area = nhood_info[:area]
  @restaurant.neighborhood = nhood_info[:neighborhood]
  @restaurant.cuisines += get_cuisine(infopage)
=end  
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

get '/delete/:rest_name/:source_name' do
  @restaurant = Restaurant.find_by(slug: params[:rest_name])
  @source = Source.find_by(slug: params[:source_name])
  erb :delete
end

post '/delete/:rest_name/:source_name' do
  @restaurant = Restaurant.find_by(slug: params[:rest_name])
  @source = Source.find_by(slug: params[:source_name])
  if params[:choice] == "total_delete"
    @restaurant.destroy
  else
    @restaurant.sources.delete(@source)
  end 
  redirect "/source/#{@source.name}"
end

get '/edit/:rest_name' do
  @restaurant = Restaurant.find_by(slug: params[:rest_name])
  erb :edit
end  

post '/edit/:rest_name' do
  @restaurant = Restaurant.find_by(slug: params[:rest_name])
  #binding.pry
=begin 
  @duplicate_restaurant = Restaurant.find_by(name: params[:restaurant][:name])
  if @duplicate_restaurant
    @duplicate_restaurant.sources += @restaurant.sources
    @duplicate_restaurant.sources.uniq!
    @restaurant.destroy
    @restaurant = @duplicate_restaurant

  else
=end
    Restaurant.update(@restaurant.id, params[:restaurant])
    @restaurant.save
    @restaurant.fill
  #end
  redirect "/rest_page/#{@restaurant.slug}"
end

get '/wtf/:rest_name/:source_name' do
  @restaurant = Restaurant.find_by(name: params[:rest_name])
  @source = Source.find_by(name: params[:source_name])
  erb :test
end


