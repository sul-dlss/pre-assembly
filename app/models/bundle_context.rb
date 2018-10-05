class BundleContext < ApplicationRecord
  belongs_to :user
  has_many :job_runs, dependent: :destroy
  before_save :output_dir_exists!, if: proc { persisted? }
  before_create :output_dir_no_exists!

  validates :bundle_dir, :content_metadata_creation, :content_structure, presence: true
  validates :project_name, presence: true, format: { with: /\A[\w-]+\z/,
                                                     message: 'only allows A-Z, a-z, 0-9, hyphen and underscore' }
  validates :staging_style_symlink, inclusion: { in: [true, false] }

  validate :verify_bundle_directory
  validate :verify_content_metadata_creation
  validate :verify_bundle_dir_path

  after_initialize :normalize_bundle_dir, :default_enums

  enum content_structure: {
    'simple_image' => 0,
    'simple_book' => 1,
    'book_as_image' => 2,
    'file' => 3,
    'smpl' => 4
  }

  enum content_metadata_creation: {
    'default' => 0,
    'filename' => 1,
    'smpl_cm_style' => 2
  }

  accepts_nested_attributes_for :job_runs

  # return [PreAssembly::Bundle]
  def bundle
    @bundle ||= PreAssembly::Bundle.new(self)
  end

  def content_md_creation
    content_metadata_creation
  end

  def project_style
    content_structure
  end

  def assembly_staging_dir
    Settings.assembly_staging_dir
  end

  def output_dir
    @output_dir ||= File.join(normalize_dir(Settings.job_output_parent_dir), user.email, project_name)
  end

  def progress_log_file
    @progress_log_file ||= File.join(output_dir, "#{project_name}_progress.yml")
  end

  # TODO: See #274. Possibly need to keep for SMPL style projects (if they don't use manifest?)
  # @deprecated - since it's not currently configurable, and non-default usage isn't tested anyway
  def stageable_discovery
    {}
  end

  # TODO: Delete everywhere in code as single commit (#227)
  def content_exclusion
    nil
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

  private

  def default_enums
    self[:content_structure] ||= 0
    self[:content_metadata_creation] ||= 0
  end

  def normalize_dir(dir)
    dir&.chomp('/')
  end

  def normalize_bundle_dir
    self[:bundle_dir] = normalize_dir(bundle_dir)
  end

  def bundle_dir_path
    return unless bundle_dir
    Pathname.new(bundle_dir).expand_path
  end

  def output_dir_exists!
    return if Dir.exist?(output_dir)
    errors.add(:bundle_dir, "Output directory (#{output_dir}) should already exist, but doesn't")
    throw(:abort)
  end

  def output_dir_no_exists!
    if Dir.exist?(output_dir)
      errors.add(:bundle_dir, "Output directory (#{output_dir}) should not already exist")
      throw(:abort)
    end
    FileUtils.mkdir_p(output_dir)
  end

  def verify_bundle_directory
    return if errors.key?(:bundle_dir)
    errors.add(:bundle_dir, "'#{bundle_dir}' not found.") unless File.directory?(bundle_dir)
  end

  def verify_content_metadata_creation
    return unless smpl_cm_style?
    errors.add(:content_metadata_creation, "The SMPL manifest #{smpl_manifest} was not found in #{bundle_dir}.") unless File.exist?(File.join(bundle_dir, smpl_manifest))
  end

  def verify_bundle_dir_path
    match_flag = nil
    bundle_dir_path&.ascend do |sub_path|
      next unless ::ALLOWABLE_BUNDLE_DIRS.include?(sub_path.to_s)
      match_flag = sub_path
      break
    end
    # match_flag = nil means we are not in the sub path, match_flag == bundle_dir_path means the user only entered the root path.
    return unless match_flag.nil? || match_flag == bundle_dir_path
    errors.add(:bundle_dir, 'not a sub directory of allowed parent directories.')
  end
end
