class BundleDirChange < ActiveRecord::Migration[7.0]
  def change
    rename_column :batch_contexts, :bundle_dir, :staging_location
  end
end
