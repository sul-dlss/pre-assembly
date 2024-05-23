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

ActiveRecord::Schema[7.1].define(version: 2024_05_17_191635) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "accessions", force: :cascade do |t|
    t.string "druid", null: false
    t.integer "version", null: false
    t.bigint "job_run_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "state", default: "in_progress", null: false
    t.index ["druid", "version", "state"], name: "index_accessions_on_druid_and_version_and_state"
    t.index ["job_run_id"], name: "index_accessions_on_job_run_id"
  end

  create_table "batch_contexts", force: :cascade do |t|
    t.string "project_name", null: false
    t.integer "content_structure", null: false
    t.string "staging_location", null: false
    t.boolean "staging_style_symlink", default: false, null: false
    t.integer "processing_configuration", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "all_files_public", default: false, null: false
    t.boolean "using_file_manifest", default: false, null: false
    t.boolean "run_ocr", default: false
    t.boolean "manually_corrected_ocr", default: false
    t.jsonb "ocr_languages", default: []
    t.index ["user_id", "project_name"], name: "index_batch_contexts_on_user_id_and_project_name", unique: true
    t.index ["user_id"], name: "index_batch_contexts_on_user_id"
  end

  create_table "globus_destinations", force: :cascade do |t|
    t.datetime "deleted_at", precision: nil
    t.bigint "batch_context_id"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "directory", null: false
    t.index ["batch_context_id"], name: "index_globus_destinations_on_batch_context_id"
    t.index ["user_id"], name: "index_globus_destinations_on_user_id"
  end

  create_table "job_runs", force: :cascade do |t|
    t.string "output_location"
    t.integer "job_type", null: false
    t.bigint "batch_context_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "state", default: "waiting", null: false
    t.text "error_message"
    t.jsonb "objects_with_error", default: [], null: false
    t.index ["batch_context_id"], name: "index_job_runs_on_batch_context_id"
    t.index ["state"], name: "index_job_runs_on_state"
  end

  create_table "users", force: :cascade do |t|
    t.string "sunet_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["sunet_id"], name: "index_users_on_sunet_id", unique: true
  end

  add_foreign_key "accessions", "job_runs"
  add_foreign_key "batch_contexts", "users"
  add_foreign_key "globus_destinations", "batch_contexts"
  add_foreign_key "globus_destinations", "users"
  add_foreign_key "job_runs", "batch_contexts"
end
