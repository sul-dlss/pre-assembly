class BundleContext < ApplicationRecord
  belongs_to :user

  validates :project_name, presence: true, null: false
  validates :content_structure, presence: true, null: false
  validates :bundle_dir, presence: true, null: false
  validates :staging_style_symlink, inclusion: { in: [ true, false ] }
  validates :content_metadata_creation, presence: true, null: false

  validate :verify_bundle_directory
  validate :verify_content_metadata_creation

  after_initialize :normalize_bundle_dir

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

  def staging_dir
    '/dor/assembly'
  end

  def normalize_bundle_dir
    self[:bundle_dir].chomp("/") if bundle_dir
  end

  def progress_log_file
    Tempfile.new.path(id) #FIXME: (#78)
  end

  def content_exclusion #FIXME: Delete everywhere in code (#227)
    nil
  end

  def file_attr
    nil # FIXME can get rid of this (#228)
  end

  def validate_files?
    false #FIXME delete everwhere in code (#230)
  end

  def content_tag_override? #TODO: find where this is used as a conditional and delete code that won't be executed (#231)
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

  # TODO: BundleContext is not really a logical home for this util method
  # load CSV allowing UTF-8 to pass through, deleting blank columns
  # @param [String] filename
  # @return [Array<ActiveSupport::HashWithIndifferentAccess>]
  # @raise if file missing/unreadable
  def self.import_csv(filename)
    raise BundleUsageError, "CSV filename required" unless filename.present?
    raise BundleUsageError, "Required file not found: #{filename}." unless File.readable?(filename)
    file_contents = IO.read(filename).encode("utf-8", replace: nil)
    csv = CSV.parse(file_contents, :headers => true)
    csv.map { |row| row.to_hash.with_indifferent_access }
  end

  # On first call, loads the manifest data, caches results
  # @return [Array<ActiveSupport::HashWithIndifferentAccess>]
  def manifest_rows
    @manifest_rows ||= self.class.import_csv(path_in_bundle(manifest))
  end

  def manifest_cols
    {
      label: 'label',
      source_id: 'sourceid',
      object_container: 'object', #object referring to filename or foldername
      druid: 'druid'
    }
  end

  private

  def verify_bundle_directory
    return if errors.key?(:bundle_dir)
    errors.add(:bundle_dir, "Bundle directory: #{bundle_dir} not found.") unless File.directory?(bundle_dir)    
  end

  def verify_content_metadata_creation
    errors.add(:content_metadata_creation, "The SMPL manifest #{smpl_manifest} was not found in #{bundle_dir}.") if smpl_style? && !File.exist?(File.join(bundle_dir, smpl_manifest)) 
  end
end
