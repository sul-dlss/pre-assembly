class BundleContext < ApplicationRecord
  belongs_to :user
  has_many :job_runs
  before_save :verify_output_dir

  validates :bundle_dir, :content_metadata_creation, :content_structure, presence: true
  validates :project_name, presence: true, format: { with: /\A[\w-]+\z/,
    message: "only allows A-Z, a-z, 0-9, hyphen and underscore" }
  validates :staging_style_symlink, inclusion: { in: [true, false] }

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
  def stageable_discovery
    {}
  end

  # TODO: delete everywhere in code as single commit (#262)
  def accession_items
    nil
  end

  # TODO: Delete everywhere in code as single commit (#227)
  def content_exclusion
    nil
  end

  # TODO: Delete everywhere in code as single commit (#228)
  def file_attr
    nil
  end

  # TODO: find where this is used as a conditional and delete code that won't be executed and this method (#231)
  def content_tag_override?
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

  # TODO: make this simpler / remove it (#329)
  def manifest_cols
    {
      label: 'label', # only used by SMPL manifests
      source_id: 'sourceid', # only used by SMPL manifests
      object_container: 'object', # object referring to filename or foldername
      druid: 'druid'
    }
  end

  private

  def job_output_parent_dir
    @job_output_parent_dir ||= Settings.job_output_parent_dir
  end

  def normalize_dir(dir)
    dir.chomp('/') if dir
  end

  def normalize_bundle_dir
    self[:bundle_dir] = normalize_dir(bundle_dir)
  end

  def verify_output_dir
    if persisted?
      # FIXME: or should we just try to create it?
      raise "Output directory (#{output_dir}) should already exist, but doesn't" unless Dir.exist?(output_dir)
    else
      raise "Output directory (#{output_dir}) should not already exist" if Dir.exist?(output_dir)
      begin
        FileUtils.mkdir_p(output_dir)
      rescue SystemCallError => e
        raise "Unable to create output directory (#{@output_dir}): #{e.message}"
      end
    end
  end

  def verify_bundle_directory
    return if errors.key?(:bundle_dir)
    errors.add(:bundle_dir, "Bundle directory: #{bundle_dir} not found.") unless File.directory?(bundle_dir)
  end

  def verify_content_metadata_creation
    return unless smpl_cm_style?
    errors.add(:content_metadata_creation, "The SMPL manifest #{smpl_manifest} was not found in #{bundle_dir}.") unless File.exist?(File.join(bundle_dir, smpl_manifest))
  end
end
