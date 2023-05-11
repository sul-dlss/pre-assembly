# frozen_string_literal: true

# Model class for the database table batch_context;
#  contains information needed to run jobs, be they discovery reports or pre_assemble runs
#  The user creates a new BatchContext by filling in the main form in the pre-assembly UI, indicating parameters common to both
#   pre-assembly and discovery report jobs.  They can then run either type of job using these common paramters by clicking a button:
#   this creates a new JobRun, which belongs_to the associated BatchContext.
# rubocop:disable Metrics/ClassLength
class BatchContext < ApplicationRecord
  # an optional manifest that provides additional detail about the files contained in each object: only used for specific jobs
  FILE_MANIFEST_FILE_NAME = 'file_manifest.csv'

  # the manifest specifying objects and associated folders on disk: required to run any job
  OBJECT_MANIFEST_FILE_NAME = 'manifest.csv'

  belongs_to :user
  has_many :job_runs, dependent: :destroy
  after_initialize :normalize_staging_location, :default_enums
  before_save :output_dir_exists!, if: proc { persisted? }
  before_create :output_dir_no_exists!

  validates :staging_location, :content_metadata_creation, :content_structure, presence: true
  validates :project_name, presence: true, format: { with: /\A[\w-]+\z/,
                                                     message: 'only allows A-Z, a-z, 0-9, hyphen and underscore' }
  validates :staging_style_symlink, :using_file_manifest, inclusion: { in: [true, false] }

  validate :verify_staging_location
  validate :verify_staging_location_path

  enum content_structure: {
    'simple_image' => 0,
    'simple_book' => 1,
    'book_as_image' => 2, # Deprecated
    'file' => 3,
    'media' => 4,
    '3d' => 5,
    'document' => 6,
    'maps' => 7,
    'webarchive_seed' => 8,
    'simple_book_rtl' => 9
  }

  # this would be better named manifest_type, but we are using the name content_metadata_creation in the UI
  enum content_metadata_creation: {
    'default' => 0,
    'filename' => 1,
    'media_cm_style' => 2 # Deprecated
  }

  accepts_nested_attributes_for :job_runs

  # return [PreAssembly::Batch]
  def batch
    @batch ||= if using_file_manifest
                 PreAssembly::Batch.new(self, file_manifest:)
               else
                 PreAssembly::Batch.new(self)
               end
  end

  def file_manifest
    PreAssembly::FileManifest.new(csv_filename: file_manifest_path,
                                  staging_location:)
  end

  # this method would be better named manifest_type, but we are using the name content_metadata_creation in the UI
  def content_md_creation
    content_metadata_creation
  end

  def project_style
    content_structure
  end

  def output_dir
    @output_dir ||= File.join(normalize_dir(Settings.job_output_parent_dir), user.email, project_name)
  end

  def progress_log_file
    @progress_log_file ||= File.join(output_dir, "#{project_name}_progress.yml")
  end

  def staging_location_with_path(rel_path)
    File.join(staging_location, rel_path)
  end

  # On first call, loads the manifest data, caches results
  # @return [Array<ActiveSupport::HashWithIndifferentAccess>]
  def object_manifest_rows
    @object_manifest_rows ||= load_object_manifest
  end

  # load the manifest.csv file and verify there is at least one object and the correct header is present
  def load_object_manifest
    raise 'manifest file missing or empty' if !File.exist?(object_manifest_path) || File.empty?(object_manifest_path)

    manifest_rows = CsvImporter.parse_to_hash(object_manifest_path)
    raise 'no rows in manifest or missing header' if manifest_rows.empty?

    columns = manifest_rows.first.keys
    raise 'manifest must have "druid" and "object" columns' unless (%w[druid object] - columns).empty?

    manifest_rows
  end

  private

  def object_manifest_path
    staging_location_with_path(OBJECT_MANIFEST_FILE_NAME)
  end

  def file_manifest_path
    staging_location_with_path(FILE_MANIFEST_FILE_NAME)
  end

  def default_enums
    self[:content_structure] ||= 0
    self[:content_metadata_creation] ||= 0
  end

  def normalize_dir(dir)
    dir&.chomp('/')
  end

  def normalize_staging_location
    self[:staging_location] = normalize_dir(staging_location)
  end

  def staging_location_path
    return unless staging_location

    Pathname.new(staging_location).expand_path
  end

  def output_dir_exists!
    return if Dir.exist?(output_dir)

    errors.add(:staging_location, "Output directory (#{output_dir}) should already exist, but doesn't")
    throw(:abort)
  end

  def output_dir_no_exists!
    if Dir.exist?(output_dir)
      errors.add(:staging_location, "Output directory (#{output_dir}) should not already exist")
      throw(:abort)
    end
    FileUtils.mkdir_p(output_dir)
  end

  # rubocop:disable Metrics/AbcSize
  def verify_staging_location
    return if errors.key?(:staging_location)
    return errors.add(:staging_location, "'#{staging_location}' not found.") unless File.directory?(staging_location)

    errors.add(:staging_location, "missing manifest: #{object_manifest_path}") unless File.exist?(object_manifest_path)
    errors.add(:staging_location, "missing file manifest: #{file_manifest_path}") if using_file_manifest && !File.exist?(file_manifest_path)
  end
  # rubocop:enable Metrics/AbcSize

  def verify_staging_location_path
    return if errors.key?(:staging_location)

    match_flag = nil
    staging_location_path&.ascend do |sub_path|
      next unless ::ALLOWABLE_STAGING_LOCATIONS.include?(sub_path.to_s)

      match_flag = sub_path
      break
    end
    # match_flag = nil means we are not in the sub path, match_flag == staging_location_path means the user only entered the root path.
    return unless match_flag.nil? || match_flag == staging_location_path

    errors.add(:staging_location, 'not a sub directory of allowed parent directories.')
  end
end
# rubocop:enable Metrics/ClassLength
