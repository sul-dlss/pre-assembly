class BundleContext < ApplicationRecord
  belongs_to :user

  validates :project_name, presence: true, null: false
  validates :content_structure, presence: true, null: false
  validates :bundle_dir, presence: true, null: false
  validates :staging_style_symlink, inclusion: { in: [ true, false ] }
  validates :content_metadata_creation, presence: true, null: false

  enum content_structure: {
    "simple_image_structure" => 0,
    "simple_book_structure" => 1,
    "book_as_iamge_structure" => 2,
    "file_structure" => 3,
    "smpl_structure" => 4
  }

  enum content_metadata_creation: {
    "default_style" => 0,
    "filename_style" => 1,
    "smpl_style" => 2
  }

end
