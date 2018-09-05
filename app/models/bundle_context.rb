class BundleContext < ApplicationRecord
  belongs_to :user

  validates :project_name, presence: true, null: false
  validates :content_structure, presence: true, null: false
  validates :bundle_dir, presence: true, null: false
  validates :staging_style_symlink, presence: true, null: false
  validates :content_metadata_creation, presence: true, null: false

  enum content_structure: {
    "simple_image" => 1,
    "simple_book" => 2,
    "book_as_iamge" => 3,
    "file" => 4,
    "smpl" => 5
  }

  enum content_metadata_creation: {
    "default" => 1,
    "filename" => 2,
    "smpl" => 3
  }

end
