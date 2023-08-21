class RenameContentMetadataCreation < ActiveRecord::Migration[7.0]
  def change
    rename_column :batch_contexts, :content_metadata_creation, :processing_configuration
  end
end
