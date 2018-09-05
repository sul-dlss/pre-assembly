class CreateBundleContexts < ActiveRecord::Migration[5.2]
  def change
    create_table :bundle_contexts do |t|
      t.string :project_name, null: false
      t.integer :content_structure, null: false
      t.string :bundle_dir, null: false
      t.boolean :staging_style_symlink, default: false, null: false
      t.integer :content_metadata_creation, null: false
      t.references :user, foreign_key: true, null: false

      t.timestamps
    end
  end
end
