class BundleContext < ApplicationRecord
  validates :project_name, presence: true, null: false
  validates :content_structure, presence: true, null: false
  validates :bundle_dir, presence: true, null: false
  validates :staging_style_symlink, presence: true, null: false
  validates :content_metadata_creation, presence: true, null: false
end
