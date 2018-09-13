class BundleContext < ApplicationRecord
  belongs_to :user
  has_many :job_runs

  validates :project_name, presence: true, null: false
  validates :content_structure, presence: true, null: false
  validates :bundle_dir, presence: true, null: false
  validates :staging_style_symlink, inclusion: { in: [true, false] }
  validates :content_metadata_creation, presence: true, null: false

  validate :verify_bundle_directory
  validate :verify_content_metadata_creation

  after_initialize :normalize_bundle_dir

  enum content_structure: {
    "simple_image" => 0,
    "simple_book" => 1,
    "book_as_image" => 2,
    "file" => 3,
    "smpl" => 4
  }

  enum content_metadata_creation: {
    "default" => 0,
    "filename" => 1,
    "smpl_cm_style" => 2
  }

  def content_md_creation
    content_metadata_creation
  end

  def project_style
    content_structure
  end

  def staging_dir
    '/tmp/assembly'
  end

  def normalize_bundle_dir
    self[:bundle_dir].chomp("/") if bundle_dir
  end

  def progress_log_file
    '/dor/preassembly' # FIXME: (#78)
  end

  def stageable_discovery
    {}
  end

  def accession_items
    nil
  end

  def content_exclusion
    # FIXME: Delete everywhere in code (#227)
    nil
  end

  def file_attr
    nil # FIXME: can get rid of this (#228)
  end

  def validate_files?
    false # FIXME: delete everwhere in code (#230)
  end

  def content_tag_override?
    # TODO: find where this is used as a conditional and delete code that won't be executed (#231)
    true
  end

  def smpl_manifest
    'smpl_manifest.csv'
  end

  def manifest
    'manifest.csv'
  end

  def path_in_bundle(rel_path)
    File.join(bundle_dir, rel_path)
  end

  # On first call, loads the manifest data, caches results
  # @return [Array<ActiveSupport::HashWithIndifferentAccess>]
  def manifest_rows
    @manifest_rows ||= CsvImporter.parse_to_hash(path_in_bundle(manifest))
  end

  def manifest_cols
    {
      label: 'label',
      source_id: 'sourceid',
      object_container: 'object', # object referring to filename or foldername
      druid: 'druid'
    }
  end

  private

  def verify_bundle_directory
    return if errors.key?(:bundle_dir)
    errors.add(:bundle_dir, "Bundle directory: #{bundle_dir} not found.") unless File.directory?(bundle_dir)
  end

  def verify_content_metadata_creation
    errors.add(:content_metadata_creation, "The SMPL manifest #{smpl_manifest} was not found in #{bundle_dir}.") if smpl_cm_style? && !File.exist?(File.join(bundle_dir, smpl_manifest))
  end
end
