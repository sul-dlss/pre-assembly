# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_04_09_210736) do

  create_table "batch_contexts", force: :cascade do |t|
    t.string "project_name", null: false
    t.integer "content_structure", null: false
    t.string "bundle_dir", null: false
    t.boolean "staging_style_symlink", default: false, null: false
    t.integer "content_metadata_creation", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "all_files_public", default: false, null: false
    t.index ["user_id", "project_name"], name: "index_batch_contexts_on_user_id_and_project_name", unique: true
    t.index ["user_id"], name: "index_batch_contexts_on_user_id"
  end

  create_table "job_runs", force: :cascade do |t|
    t.string "output_location"
    t.integer "job_type", null: false
    t.integer "batch_context_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["batch_context_id"], name: "index_job_runs_on_batch_context_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "sunet_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sunet_id"], name: "index_users_on_sunet_id", unique: true
  end

  add_foreign_key "batch_contexts", "users"
end
