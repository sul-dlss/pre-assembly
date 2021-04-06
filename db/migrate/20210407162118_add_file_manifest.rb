class AddFileManifest < ActiveRecord::Migration[6.1]
  def change
    add_column :batch_contexts, :using_file_manifest, :boolean, default: false, null: false
  end
end
