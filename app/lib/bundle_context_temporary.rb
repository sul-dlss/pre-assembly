class BundleUsageError < StandardError
  # An exception class used to pass usage error messages
  # back to users of the bin/pre-assemble script.
end

# This is a temporary BundleConext class that will be replaced with the BundleContext ActiveRecord Model.
class BundleContextTemporary
  # Paramaters passed via YAML config files.
  YAML_PARAMS = [
    :project_style,
    :bundle_dir,
    :staging_dir,
    :accession_items,
    :manifest,
    :checksums_file,
    :progress_log_file,
    :project_name,
    :file_attr,
    :content_md_creation,
    :stageable_discovery,
    :manifest_cols,
    :content_exclusion,
    :config_filename,
    :validate_files,
    :staging_style
  ]

  YAML_PARAMS.each { |p| attr_accessor p }

  attr_accessor :user_params
  attr_writer :manifest_rows

  # Unpack the user-supplied parameters, after converting
  # all hash keys and some hash values to symbols.
  def initialize(params = {})
    params = Assembly::Utils.symbolize_keys params
    Assembly::Utils.values_to_symbols! params[:project_style]
    cmc          = params[:content_md_creation]
    cmc[:style]  = cmc[:style].to_sym
    params[:file_attr] ||= params[:publish_attr]
    self.user_params = params
    YAML_PARAMS.each { |p| instance_variable_set "@#{p}", params[p] }
    setup_paths
    setup_other
    setup_defaults
    validate_usage
  end

  def validate_files?
    return @validate_files unless @validate_files.nil?
    false
  end

  ####
  # grab bag
  ####

  # TODO: BundleContext is not really a logical home for this util method
  # load CSV into an array of hashes, allowing UTF-8 to pass through, deleting blank columns
  def self.import_csv(filename)
    file_contents = IO.read(filename).encode("utf-8", replace: nil)
    csv = CSV.parse(file_contents, :headers => true)
    csv.map { |row| row.to_hash.with_indifferent_access }
  end

  def path_in_bundle(rel_path)
    File.join(bundle_dir, rel_path)
  end

  # On first call, loads the manifest data (does not reload on subsequent calls).
  # If bundle is not using a manifest, just loads and returns emtpy array.
  def manifest_rows
    @manifest_rows ||= self.class.import_csv(manifest)
  end

  ####
  # initialization helpers
  ####

  def setup_paths
    bundle_dir.chomp!('/') # get rid of any trailing slash on the bundle directory
    self.manifest       &&= path_in_bundle(manifest)
    self.checksums_file &&= path_in_bundle(checksums_file)
    self.staging_dir = Assembly::ASSEMBLY_WORKSPACE if staging_dir.nil? # if the user didn't supply a staging_dir, use the default
    self.progress_log_file = File.join(File.dirname(config_filename), File.basename(config_filename, '.yaml') + '_progress.yaml') unless progress_log_file # if the user didn't supply a progress log file, use the yaml config file as a base, and add '_progress'
  end

  def setup_other
    self.content_exclusion &&= Regexp.new(content_exclusion)
    self.file_attr            ||= {}
    self.file_attr.delete_if { |_k, v| v.nil? }
  end

  def setup_defaults
    self.validate_files = true if @validate_files.nil? # FIXME: conflict between attribute and non-getter method #validate_files
    self.staging_style ||= 'copy'
    project_style[:content_tag_override] = false if project_style[:content_tag_override].nil?
    content_md_creation[:smpl_manifest] ||= 'smpl_manifest.csv'
  end

  ####
  # Usage validation.
  ####

  # allowed controlled vocabulary for various configuration paramaters
  def allowed_values
    {
      :project_style => {
        :content_structure => [:simple_image, :simple_book, :book_as_image, :book_with_pdf, :file, :smpl],
        :get_druid_from => [:container, :manifest, :suri, :druid_minter],
      },
      :content_md_creation => {
        :style => [:default, :filename, :dpg, :smpl, :salt, :none],
      }
    }
  end

  def required_dirs
    [bundle_dir, staging_dir]
  end

  # If a file parameter from the YAML is non-nil, the file must exist.
  def required_files
    [
      manifest,
      checksums_file
    ].compact
  end

  def required_user_params
    YAML_PARAMS - non_required_user_params
  end

  def non_required_user_params
    [
      :config_filename,
      :validate_files,
      :staging_style,
    ]
  end

  # Validate parameters supplied via user script.
  # Unit testing often bypasses such checks.
  def validate_usage
    validation_errors = []

    required_user_params.each do |p|
      next if user_params.has_key? p
      validation_errors << "Missing parameter: #{p}."
    end

    required_dirs.each do |d|
      next if File.directory? d
      validation_errors << "Required directory not found: #{d}."
    end

    required_files.each do |f|
      next if File.readable? f
      validation_errors << "Required file not found: #{f}."
    end

    validation_errors << "Bundle directory not specified." if bundle_dir.nil? || bundle_dir == ''
    validation_errors << "Bundle directory #{bundle_dir} not found." unless File.directory?(bundle_dir)
    validation_errors << "Staging directory '#{staging_dir}' not writable." unless File.writable?(staging_dir)
    validation_errors << "Progress log file '#{progress_log_file}' or directory not writable." unless File.writable?(File.dirname(progress_log_file))

    # validation_errors << "The APO and SET DRUIDs should not be set." if apo_druid_id # APO should not be set
    # validation_errors << "get_druid_from: 'suri' is no longer valid" if project_style[:get_druid_from] == :suri # can't use SURI to get druid
    if manifest.blank?
      validation_errors << "A manifest file must be provided."
    elsif manifest_rows.size == 0
      validation_errors << "Manifest does not have any rows!"
    elsif manifest_cols.blank? || manifest_cols[:object_container].blank?
      validation_errors << "You must specify the name of your column which represents your object container in a parameter called 'object_container' under 'manifest_cols'"
    else
      first_row_keys = manifest_rows.first.keys
      validation_errors << "Manifest does not have a column called '#{manifest_cols[:object_container]}'"                            unless first_row_keys.include?(manifest_cols[:object_container].to_s)
      validation_errors << "Manifest does not have a column called '#{manifest_cols[:source_id]}'" if !manifest_cols[:source_id].blank? && !first_row_keys.include?(manifest_cols[:source_id].to_s)
      validation_errors << "Manifest does not have a column called '#{manifest_cols[:label]}'" if !manifest_cols[:label].blank?         && !first_row_keys.include?(manifest_cols[:label].to_s)
      validation_errors << "You must have a column labeled 'druid' in your manifest" unless first_row_keys.include?('druid')
    end

    if stageable_discovery[:use_container] # if we are staging the whole container, check some stuff
      validation_errors << "If stageable_discovery:use_container=true, you cannot use get_druid_from='container'." if project_style[:get_druid_from].to_s =~ /^container/ # if you are staging the entire container, it doesn't make sense to use the container to get the druid
    else # if we are not staging the whole container, check some stuff
      validation_errors << "If stageable_discovery:use_container=false, you must set a glob to discover files in each container." if stageable_discovery[:glob].blank? # glob must be set
    end

    # check parameters that are part of a controlled vocabulary to be sure they don't have bogus values
    validation_errors << "The project_style:content_structure value of '#{project_style[:content_structure]}' is not valid." unless allowed_values[:project_style][:content_structure].include? project_style[:content_structure]
    validation_errors << "The project_style:get_druid_from value of '#{project_style[:get_druid_from]}' is not valid." unless allowed_values[:project_style][:get_druid_from].include? project_style[:get_druid_from]
    validation_errors << "The content_md_creation:style value of '#{content_md_creation[:style]}' is not valid." unless allowed_values[:content_md_creation][:style].include? content_md_creation[:style]

    validation_errors << "The SMPL manifest #{content_md_creation[:smpl_manifest]} was not found in #{bundle_dir}." if content_md_creation[:style] == :smpl && !File.exist?(File.join(bundle_dir, content_md_creation[:smpl_manifest]))

    unless validation_errors.blank?
      validation_errors = ['Configuration errors found:'] + validation_errors
      raise BundleUsageError, validation_errors.join('  ') unless validation_errors.blank?
    end
  end
end
