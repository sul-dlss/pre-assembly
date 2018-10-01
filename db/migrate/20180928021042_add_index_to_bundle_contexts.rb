class AddIndexToBundleContexts < ActiveRecord::Migration[5.2]
  def change
    add_index :bundle_contexts, [:user_id, :project_name], :unique => true
  end
end
