# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20130814233404) do

  create_table "areas", force: true do |t|
    t.string "name"
    t.string "slug"
  end

  create_table "base_sources", force: true do |t|
    t.string  "name"
    t.string  "base_url"
    t.text    "bad_names"
    t.boolean "public_source"
  end

  create_table "cuisines", force: true do |t|
    t.string "name"
    t.string "slug"
  end

  create_table "cuisines_restaurants", id: false, force: true do |t|
    t.integer "cuisine_id",    null: false
    t.integer "restaurant_id", null: false
  end

  create_table "friendships", force: true do |t|
    t.integer "user_id"
    t.integer "friend_id"
    t.string  "status"
  end

  create_table "neighborhoods", force: true do |t|
    t.string  "name"
    t.integer "area_id"
    t.string  "slug"
  end

  create_table "notes", force: true do |t|
    t.integer "restaurant_id"
    t.integer "user_id"
    t.string  "content"
  end

  create_table "permissions", force: true do |t|
    t.integer  "user_id"
    t.integer  "source_id"
    t.string   "status"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "restaurants", force: true do |t|
    t.string   "name"
    t.string   "slug"
    t.string   "menulink"
    t.string   "address"
    t.string   "cross_street"
    t.string   "area"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "neighborhood_id"
  end

  create_table "restaurants_sources", id: false, force: true do |t|
    t.integer "restaurant_id", null: false
    t.integer "source_id",     null: false
  end

  create_table "sources", force: true do |t|
    t.string  "name"
    t.string  "slug"
    t.string  "url"
    t.string  "description"
    t.integer "base_source_id"
  end

  create_table "users", force: true do |t|
    t.string "name"
    t.string "email"
    t.string "salt"
    t.string "passwordhash"
  end

  create_table "users_visits", id: false, force: true do |t|
    t.integer "user_id",  null: false
    t.integer "visit_id", null: false
  end

  create_table "visits", force: true do |t|
    t.date    "date"
    t.integer "restaurant_id"
    t.string  "notes"
  end

end
