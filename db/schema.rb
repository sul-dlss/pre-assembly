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

ActiveRecord::Schema.define(version: 2018_09_10_225753) do

  create_table "bundle_contexts", force: :cascade do |t|
    t.string "project_name", null: false
    t.integer "content_structure", null: false
    t.string "bundle_dir", null: false
    t.boolean "staging_style_symlink", default: false, null: false
    t.integer "content_metadata_creation", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_bundle_contexts_on_user_id"
  end

  create_table "job_runs", force: :cascade do |t|
    t.string "output_location"
    t.integer "job_type"
    t.integer "bundle_context_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bundle_context_id"], name: "index_job_runs_on_bundle_context_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "sunet_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sunet_id"], name: "index_users_on_sunet_id", unique: true
  end

end
