# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_10_060015) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "unaccent"

  create_table "business_rubros", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.bigint "rubro_id", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "rubro_id"], name: "index_business_rubros_on_business_id_and_rubro_id", unique: true
    t.index ["business_id"], name: "index_business_rubros_on_business_id"
    t.index ["rubro_id"], name: "index_business_rubros_on_rubro_id"
  end

  create_table "businesses", force: :cascade do |t|
    t.string "address"
    t.string "business_status"
    t.bigint "comuna_id", null: false
    t.datetime "created_at", null: false
    t.string "digital_presence"
    t.decimal "lat", precision: 10, scale: 6
    t.decimal "lead_score", precision: 8, scale: 3, default: "0.0", null: false
    t.decimal "lng", precision: 10, scale: 6
    t.string "name", null: false
    t.string "phone"
    t.string "pipeline_stage", default: "nuevo", null: false
    t.string "place_id"
    t.boolean "places_expired", default: false, null: false
    t.boolean "pos_candidate", default: false, null: false
    t.string "pos_status", default: "desconocido", null: false
    t.string "pos_vendor"
    t.decimal "rating", precision: 2, scale: 1
    t.string "source", default: "places", null: false
    t.datetime "synced_at"
    t.jsonb "types", default: [], null: false
    t.datetime "updated_at", null: false
    t.integer "user_rating_count", default: 0, null: false
    t.string "website_uri"
    t.index ["business_status"], name: "index_businesses_on_business_status"
    t.index ["comuna_id"], name: "index_businesses_on_comuna_id"
    t.index ["digital_presence"], name: "index_businesses_on_digital_presence"
    t.index ["lead_score"], name: "index_businesses_on_lead_score"
    t.index ["pipeline_stage"], name: "index_businesses_on_pipeline_stage"
    t.index ["place_id"], name: "index_businesses_on_place_id", unique: true, where: "(place_id IS NOT NULL)"
    t.index ["source"], name: "index_businesses_on_source"
  end

  create_table "comunas", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "region", default: "Maule", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_comunas_on_name", unique: true
  end

  create_table "contact_events", force: :cascade do |t|
    t.text "body"
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.datetime "occurred_at", null: false
    t.string "product"
    t.datetime "updated_at", null: false
    t.index ["business_id", "occurred_at"], name: "index_contact_events_on_business_id_and_occurred_at"
    t.index ["business_id"], name: "index_contact_events_on_business_id"
  end

  create_table "rubros", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "label", null: false
    t.boolean "pos_target", default: false, null: false
    t.string "text_search_query", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_rubros_on_key", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "sync_runs", force: :cascade do |t|
    t.integer "api_calls", default: 0, null: false
    t.bigint "comuna_id", null: false
    t.datetime "created_at", null: false
    t.integer "error_count", default: 0, null: false
    t.datetime "finished_at"
    t.integer "found_count", default: 0, null: false
    t.integer "new_count", default: 0, null: false
    t.text "notes"
    t.string "query"
    t.bigint "rubro_id", null: false
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.integer "updated_count", default: 0, null: false
    t.index ["comuna_id"], name: "index_sync_runs_on_comuna_id"
    t.index ["created_at"], name: "index_sync_runs_on_created_at"
    t.index ["rubro_id"], name: "index_sync_runs_on_rubro_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "business_rubros", "businesses"
  add_foreign_key "business_rubros", "rubros"
  add_foreign_key "businesses", "comunas"
  add_foreign_key "contact_events", "businesses"
  add_foreign_key "sessions", "users"
  add_foreign_key "sync_runs", "comunas"
  add_foreign_key "sync_runs", "rubros"
end
