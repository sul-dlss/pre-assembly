class AddPublicToBundleContext < ActiveRecord::Migration[5.2]
  def change

    add_column :bundle_contexts, :all_files_public, :boolean, default: false, null: false
  end
end
