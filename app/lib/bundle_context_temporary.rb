class BundleUsageError < StandardError
  # An exception class used to pass usage error messages
  # back to users of the bin/pre-assemble script.
end

# This is a temporary BundleConext class that will be replaced with the BundleContext ActiveRecord Model.
class BundleContextTemporary
  # Paramaters passed via YAML config files.
  YAML_PARAMS = [
    :accession_items,
    :bundle_dir,
    :config_filename,
    :content_exclusion,
    :content_md_creation,
    :file_attr,
    :manifest_cols,
    :manifest,
    :progress_log_file,
    :project_name,
    :project_style,
    :stageable_discovery,
    :staging_dir,
    :staging_style,
    :validate_files
  ]

  YAML_PARAMS.each { |p| attr_accessor p }

  attr_accessor :user_params
  attr_writer :manifest_rows

  # Unpack the user-supplied parameters, after converting
  # all hash keys and some hash values to symbols.
  def initialize(params)
    params.deep_symbolize_keys!
    raise ArgumentError, ':bundle_dir is required' unless params[:bundle_dir] # TODO: replace w/ AR validation
    [:content_md_creation, :project_style, :stageable_discovery].each { |k| params[k] ||= {} }
    params[:project_style].transform_values! { |v| v.is_a?(String) ? v.to_sym : v }
    params[:project_style][:content_structure] ||= :simple_image
    params[:content_md_creation][:style] ||= :default
    params[:content_md_creation][:style] = params[:content_md_creation][:style].to_sym
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

  def path_in_bundle(rel_path)
    File.join(bundle_dir, rel_path)
  end

  # On first call, loads the manifest data, caches results
  # @return [Array<ActiveSupport::HashWithIndifferentAccess>]
  def manifest_rows
    @manifest_rows ||= CsvImporter.parse_to_hash(manifest)
  end

  ####
  # initialization helpers
  ####

  def setup_paths
    bundle_dir.chomp!('/') # get rid of any trailing slash on the bundle directory
    self.manifest &&= path_in_bundle(manifest)
    self.staging_dir ||= '/dor/assembly'
    self.progress_log_file ||= File.join(File.dirname(config_filename), File.basename(config_filename, '.yaml') + '_progress.yaml')
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
      },
      :content_md_creation => {
        :style => [:default, :filename, :dpg, :smpl, :salt, :none],
      }
    }
  end

  def required_dirs
    [bundle_dir, staging_dir]
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

    validation_errors << "Bundle directory not specified." if bundle_dir.nil? || bundle_dir == ''
    validation_errors << "Bundle directory #{bundle_dir} not found." unless File.directory?(bundle_dir)
    validation_errors << "Staging directory '#{staging_dir}' not writable." unless File.writable?(staging_dir)
    validation_errors << "Progress log file '#{progress_log_file}' or directory not writable." unless File.writable?(File.dirname(progress_log_file))

    # validation_errors << "The APO and SET DRUIDs should not be set." if apo_druid_id # APO should not be set
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
      validation_errors << "Manifest does not have a column called 'druid'" unless first_row_keys.include?('druid')
    end

    # check parameters that are part of a controlled vocabulary to be sure they don't have bogus values
    validation_errors << "The project_style:content_structure value of '#{project_style[:content_structure]}' is not valid." unless allowed_values[:project_style][:content_structure].include? project_style[:content_structure]
    validation_errors << "The content_md_creation:style value of '#{content_md_creation[:style]}' is not valid." unless allowed_values[:content_md_creation][:style].include? content_md_creation[:style]
    validation_errors << "The SMPL manifest #{content_md_creation[:smpl_manifest]} was not found in #{bundle_dir}." if content_md_creation[:style] == :smpl && !File.exist?(File.join(bundle_dir, content_md_creation[:smpl_manifest]))

    unless validation_errors.blank?
      validation_errors = ['Configuration errors found:'] + validation_errors
      raise BundleUsageError, validation_errors.join('  ') unless validation_errors.blank?
    end
  end
end
