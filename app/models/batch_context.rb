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
  has_one :globus_destination, dependent: :destroy
  after_initialize :normalize_staging_location, :default_enums
  before_validation :set_using_file_manifest
  before_save :set_processing_configuration, if: proc { Settings.ocr.enabled }
  before_save :output_dir_exists!, if: proc { persisted? }
  before_create :output_dir_no_exists!

  validates :staging_location, :content_structure, presence: true
  # we only need this validation when OCR is disabled (once enabled, the processing_configuration is set automatically based on content type)
  validates :processing_configuration, presence: true, unless: proc { Settings.ocr.enabled }
  validates :project_name, presence: true, format: { with: /\A[\w-]+\z/,
                                                     message: 'only allows A-Z, a-z, 0-9, hyphen and underscore' }
  validates :staging_style_symlink, :using_file_manifest, inclusion: { in: [true, false] }

  validate :verify_staging_location
  validate :verify_staging_location_path
  validate :verify_file_manifest_exists, if: :using_file_manifest
  validate :verify_output_dir_no_exists, unless: proc { persisted? }

  enum :content_structure, {
    simple_image: 0,
    simple_book: 1,
    book_as_image: 2, # Deprecated
    file: 3,
    media: 4,
    '3d' => 5,
    document: 6,
    maps: 7,
    webarchive_seed: 8,
    simple_book_rtl: 9, # Deprecated
    geo: 10
  }

  enum :processing_configuration, {
    default: 0,
    filename: 1,
    media_cm_style: 2, # Deprecated
    filename_with_ocr: 3 # Deprecated
  }
  # sets required processing_configuration values for a given content structure
  CONTENT_STRUCTURE_TO_PROCESSING_CONFIGURATION = {
    'simple_image' => 'filename',
    'simple_book' => 'filename',
    'document' => 'default',
    'file' => 'default',
    'geo' => 'default',
    'media' => 'default',
    '3d' => 'default',
    'maps' => 'filename',
    'webarchive_seed' => 'default'
  }.freeze

  accepts_nested_attributes_for :job_runs

  def project_style
    content_structure
  end

  def output_dir
    @output_dir ||= File.join(normalize_dir(Settings.job_output_parent_dir), user&.email, project_name)
  end

  def progress_log_file
    @progress_log_file ||= File.join(output_dir, "#{project_name}_progress.yml")
  end

  def progress_log_file_exists?
    progress_log_file && File.exist?(progress_log_file)
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

  def file_manifest_path
    staging_location_with_path(FILE_MANIFEST_FILE_NAME)
  end

  def active_globus_url
    return nil unless globus_destination.present? && globus_destination.deleted_at.blank?

    globus_destination.url
  end

  # helper method to check if any associated job_runs have completed accessioning
  def accessioning_complete?
    job_runs.present? && job_runs.any?(&:accessioning_complete?)
  end

  private

  # media content structure requires a file manifest, and we don't even ask the user about it in the UI
  def set_using_file_manifest
    self.using_file_manifest = true if content_structure == 'media'
  end

  # set the processing configuration based on the content structure
  def set_processing_configuration
    self.processing_configuration = CONTENT_STRUCTURE_TO_PROCESSING_CONFIGURATION[content_structure]
  end

  def object_manifest_path
    staging_location_with_path(OBJECT_MANIFEST_FILE_NAME)
  end

  def default_enums
    self[:processing_configuration] ||= 0
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

  def verify_output_dir_no_exists
    return unless Dir.exist?(output_dir)

    errors.add(:staging_location, "Output directory (#{output_dir}) should not already exist")
  rescue TypeError
    # Indicates that user email or project_name are missing.
    # However, these are validated separately, so OK to ignore here.
  end

  def verify_staging_location
    return if errors.key?(:staging_location)
    return errors.add(:staging_location, "'#{staging_location}' not found.") unless File.directory?(staging_location)

    errors.add(:staging_location, "missing manifest: #{object_manifest_path}") unless File.exist?(object_manifest_path)
  end

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

  def verify_file_manifest_exists
    errors.add(:staging_location, ": file manifest missing or empty: #{file_manifest_path}") unless File.exist?(file_manifest_path) && !File.empty?(file_manifest_path)
  end
end
# rubocop:enable Metrics/ClassLength
