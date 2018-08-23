# encoding: UTF-8

require 'csv'
require 'ostruct'
require 'pathname'

module PreAssembly
  class BundleUsageError < StandardError
    # An exception class used to pass usage error messages
    # back to users of the bin/pre-assemble script.
  end

  class Bundle
    include PreAssembly::Logging
    include PreAssembly::Reporting

    # Paramaters passed via YAML config files.
    YAML_PARAMS = [
      :project_style,
      :bundle_dir,
      :staging_dir,
      :accession_items,
      :manifest,
      :checksums_file,
      :desc_md_template,
      :progress_log_file,
      :project_name,
      :apply_tag,
      :apo_druid_id,
      :set_druid_id,
      :file_attr,
      :compute_checksum,
      :init_assembly_wf,
      :content_md_creation,
      :object_discovery,
      :stageable_discovery,
      :manifest_cols,
      :content_exclusion,
      :validate_usage,
      :show_progress,
      :limit_n,
      :uniqify_source_ids,
      :cleanup,
      :resume,
      :config_filename,
      :validate_files,
      :new_druid_tree_format,
      :validate_bundle_dir,
      :throttle_time,
      :staging_style
    ]

    attr_writer :manifest_rows, :provider_checksums
    attr_accessor :user_params,
                  :digital_objects,
                  :skippables,
                  :smpl_manifest,
                  :desc_md_template_xml

    YAML_PARAMS.each { |p| attr_accessor p }

    ####
    # Initialization.
    ####

    # load CSV into an array of hashes, allowing UTF-8 to pass through, deleting blank columns
    def self.import_csv(filename)
      file_contents = IO.read(filename).encode("utf-8", replace: nil)
      csv = CSV.parse(file_contents, :headers => true)
      csv.map { |row| row.to_hash.with_indifferent_access }
      # return CsvMapper.import(filename) do read_attributes_from_file end
    end

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

      # Other setup work.
      setup_paths
      setup_other
      setup_defaults
      validate_usage
      show_developer_setting_warning
      load_desc_md_template
      load_skippables
    end

    def setup_paths
      self.manifest       &&= path_in_bundle(manifest)
      self.checksums_file &&= path_in_bundle(checksums_file)
      if !desc_md_template.nil? && !(Pathname.new desc_md_template).absolute? # check for a desc MD template being defined and not being absolute
        self.desc_md_template = path_in_bundle(desc_md_template) # set it relative to the bundle
      end
      self.staging_dir = Assembly::ASSEMBLY_WORKSPACE if staging_dir.nil? # if the user didn't supply a staging_dir, use the default
      self.progress_log_file = File.join(File.dirname(config_filename), File.basename(config_filename, '.yaml') + '_progress.yaml') unless progress_log_file # if the user didn't supply a progress log file, use the yaml config file as a base, and add '_progress'
    end

    def setup_other
      self.digital_objects        = []
      self.skippables             = {}
      self.content_exclusion &&= Regexp.new(content_exclusion)
      self.validate_bundle_dir  ||= {}
      self.file_attr            ||= {}
      self.file_attr.delete_if { |_k, v| v.nil? }
      self.set_druid_id = [set_druid_id] if set_druid_id && set_druid_id.is_a?(String) # convert set_druid_id to 1 element array if its single valued and exists
    end

    def setup_defaults
      self.validate_files = true if @validate_files.nil? # FIXME: conflict between attribute and non-getter method #validate_files
      self.new_druid_tree_format = true if new_druid_tree_format.nil?
      self.throttle_time ||= 0
      self.staging_style ||= 'copy'
      project_style[:content_tag_override] = false if project_style[:content_tag_override].nil?
      content_md_creation[:smpl_manifest] ||= 'smpl_manifest.csv'
    end

    def load_desc_md_template
      return nil unless desc_md_template && File.readable?(desc_md_template)
      self.desc_md_template_xml = IO.read(desc_md_template)
    end

    def load_skippables
      return unless resume
      docs = YAML.load_stream(Assembly::Utils.read_file(progress_log_file))
      docs = docs.documents if docs.respond_to? :documents
      docs.each do |yd|
        skippables[yd[:unadjusted_container]] = true if yd[:pre_assem_finished]
      end
    end

    ####
    # Usage validation.
    ####

    # allowed controlled vocabulary for various configuration paramaters
    def allowed_values
      {
        :project_style => {
          :content_structure => [:simple_image, :simple_book, :book_as_image, :book_with_pdf, :file, :smpl],
          :get_druid_from => [:suri, :container, :container_barcode, :manifest, :druid_minter],
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
        checksums_file,
        desc_md_template,
        validate_bundle_dir[:code],
      ].compact
    end

    def required_user_params
      YAML_PARAMS - non_required_user_params
    end

    def non_required_user_params
      [
        :config_filename,
        :validate_files,
        :new_druid_tree_format,
        :staging_style,
        :validate_bundle_dir,
        :throttle_time,
        :apply_tag
      ]
    end

    # spit out some dire warning messages if you set certain parameters that are only applicable for developers
    def show_developer_setting_warning
      warning = []
      warning << '* get_druid_from=druid_minter' if project_style[:get_druid_from] == :druid_minter
      warning << '* init_assembly_wf=false' unless init_assembly_wf
      warning << '* uniqify_source_ids=true' if uniqify_source_ids
      warning << '* cleanup=true' if @cleanup
      puts "\n***DEVELOPER MODE WARNING: You have set some parameters typically only set by developers****\n#{warning.join("\n")}" if show_progress && warning.size > 0
    end

    # Validate parameters supplied via user script.
    # Unit testing often bypasses such checks.
    def validate_usage
      return unless @validate_usage # FIXME: attribute/method name conflict

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
      bundle_dir.chomp!('/') # get rid of any trailing slash on the bundle directory
      validation_errors <<  "Bundle directory #{bundle_dir} not found." unless File.directory?(bundle_dir)

      validation_errors <<  "Staging directory '#{staging_dir}' not writable." unless File.writable?(staging_dir)
      validation_errors <<  "Progress log file '#{progress_log_file}' or directory not writable." unless File.writable?(File.dirname(progress_log_file))

      if project_style[:should_register] # if should_register=true, check some stuff
        validation_errors << "The APO DRUID must be set if should_register = true." if apo_druid_id.blank? # APO can't be blank
        validation_errors << "get_druid_from: 'manifest' is only valid if should_register = false." if project_style[:get_druid_from] == :manifest # can't use manifest to get druid if not yet registered
        validation_errors << "If should_register=true, then you must use a manifest." unless object_discovery[:use_manifest] # you have to use a manifest if you want to register objects
        validation_errors << "If should_register=true, it does not make sense to have project_style:content_tag_override=true since objects are not registered yet." if project_style[:content_tag_override]
      else # if should_register=false, check some stuff
        if project_style[:get_druid_from] != :container_barcode
          validation_errors << "The APO and SET DRUIDs should not be set if should_register = false." if (apo_druid_id || set_druid_id) # APO and SET should not be set
        else
          validation_errors << "The APO DRUID must be set if project_style:get_druid_from = container_barcode." if apo_druid_id.blank? # APO DRUID must be added for container_barcode projects
          validation_errors << "The SET DRUID should not be set if project_style:get_druid_from = container_barcode." if set_druid_id # SET DRUID must not be set for container_barcode projects
        end
        validation_errors << "get_druid_from: 'suri' is only valid if should_register = true." if project_style[:get_druid_from] == :suri # can't use SURI to get druid
        validation_errors << "get_druid_from: 'manifest' is only valid if use_manifest = true." if project_style[:get_druid_from] == :manifest && object_discovery[:use_manifest] == false # can't use SURI to get druid
      end

      if object_discovery[:use_manifest] # if we are using a manifest, check some stuff
        validation_errors << "The glob and regex for object_discovery should not be set if object_discovery:use_manifest=true." unless object_discovery[:glob].nil? && object_discovery[:regex].nil? # glob and regex should be nil
        if manifest.blank?
          validation_errors << "A manifest file must be provided if object_discovery:use_manifest=true." # you need a manifest file!
        else # let's see if the columns the user claims are there exist in the actual manifest
          if manifest_rows.size == 0
            validation_errors << "Manifest does not have any rows!"
          elsif manifest_cols.blank? || manifest_cols[:object_container].blank?
            validation_errors << "You must specify the name of your column which represents your object container in a parameter called 'object_container' under 'manifest_cols'"
          else
            validation_errors << "Manifest does not have a column called '#{manifest_cols[:object_container]}'" unless manifest_rows.first.keys.include?(manifest_cols[:object_container].to_s)
            validation_errors << "You must define a label and source_id column in the manifest if should_register=true" if (manifest_cols[:source_id].blank? || manifest_cols[:label].blank?) && project_style[:should_register] # if this is a project with should_register=true, we always need a source ID and a label column
            validation_errors << "Manifest does not have a column called '#{manifest_cols[:source_id]}'" if !manifest_cols[:source_id].blank? && !manifest_rows.first.keys.include?(manifest_cols[:source_id].to_s)
            validation_errors << "Manifest does not have a column called '#{manifest_cols[:label]}'" if !manifest_cols[:label].blank? && !manifest_rows.first.keys.include?(manifest_cols[:label].to_s)
            validation_errors << "You must have a column labeled 'druid' in your manifest if you want to use project_style:get_druid_from=manifest" if project_style[:get_druid_from] == :manifest && !manifest_rows.first.keys.include?('druid')
          end
        end
      else # if we are not using a manifest, check some stuff
        validation_errors << "The glob for object_discovery must be set if object_discovery:use_manifest=false." if object_discovery[:glob].blank? # glob must be set
        validation_errors << "Manifest and desc_md_template files should be set to nil if object_discovery:use_manifest=false." unless manifest.blank? && desc_md_template.blank?
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

    ####
    # The main process.
    ####

    # Runs the pre-assembly process and returns an array of PIDs of the digital objects processed.
    def run_pre_assembly
      log ""
      log "run_pre_assembly(#{run_log_msg})"
      puts "#{Time.now}: Pre-assembly started for #{project_name}" if show_progress

      return unless bundle_directory_is_valid?

      # load up the SMPL manifest if we are using that style
      if content_md_creation[:style] == :smpl
        self.smpl_manifest = PreAssembly::Smpl.new(:csv_filename => content_md_creation[:smpl_manifest], :bundle_dir => bundle_dir, :verbose => false)
      end
      discover_objects
      process_manifest
      process_digital_objects
      delete_digital_objects
      puts "#{Time.now}: Pre-assembly completed for #{project_name}" if show_progress
      processed_pids
    end

    def run_log_msg
      log_params = {
        :project_style => project_style,
        :project_name  => project_name,
        :bundle_dir    => bundle_dir,
        :staging_dir   => staging_dir,
        :environment   => ENV['RAILS_ENV'],
        :resume        => resume,
      }
      log_params.map { |k, v| "#{k}=#{v.inspect}" }.join(', ')
    end

    def processed_pids
      digital_objects.map(&:pid)
    end

    def object_filenames_unique?(dobj)
      filenames = dobj.object_files.map { |objfile| File.basename(objfile.path) }
      filenames.count == filenames.uniq.count
    end

    def object_files_exist?(dobj)
      return false if dobj.object_files.size == 0
      dobj.object_files.map(&:path).all? { |path| File.readable?(path) }
    end

    # Cleanup of objects and associated files in specified environment using logfile as input
    def cleanup(steps = [], dry_run = false)
      log "cleanup()"
      unless File.exist?(progress_log_file)
        puts "#{progress_log_file} not found!  Cannot proceed"
        return
      end
      druids = Assembly::Utils.get_druids_from_log(progress_log_file)
      Assembly::Utils.cleanup(:druids => druids, :steps => steps, :dry_run => dry_run)
    end

    ####
    # Validate the bundle_dir directory structure, if the client supplied
    # validating code.
    ####

    def bundle_directory_is_valid?(_io = STDOUT)
      # Do nothing if no validation code was supplied.
      return true unless validate_bundle_dir[:code]
      # Run validations and return true/false accordingly.
      dv = run_dir_validation_code()
      dv.validate
      return true if dv.warnings.size == 0
      write_validation_warnings(dv)
      false
    end

    # Require the DirValidator code, run it, and return the validator.
    def run_dir_validation_code
      require validate_bundle_dir[:code] # FIXME: Security hazard
      PreAssembly.validate_bundle_directory(bundle_dir)
    end

    def write_validation_warnings(validator, io = STDOUT)
      r  = validate_bundle_dir[:report]
      fh = File.open(r, 'w')
      validator.report(fh)
      io.puts("Bundle directory failed validation: see #{r}")
    end

    ####
    # Discovery of object containers and stageable items.
    ####

    # Discovers the digital object containers and the stageable items within them.
    # For each container, creates a new Digitalobject.
    def discover_objects
      log "discover_objects()"
      object_containers.each do |c|
        container    = actual_container(c)
        stageables   = stageable_items_for(c)
        object_files = discover_object_files(stageables)
        params = {
          :project_style        => project_style,
          :bundle_dir           => bundle_dir,
          :staging_dir          => staging_dir,
          :project_name         => project_name,
          :apply_tag            => apply_tag,
          :apo_druid_id         => apo_druid_id,
          :set_druid_id         => set_druid_id,
          :file_attr            => file_attr,
          :init_assembly_wf     => init_assembly_wf,
          :content_md_creation  => content_md_creation,
          :container            => container,
          :unadjusted_container => c,
          :stageable_items      => stageables,
          :object_files         => object_files,
          :new_druid_tree_format => new_druid_tree_format,
          :staging_style        => staging_style,
          :smpl_manifest        => smpl_manifest
        }
        dobj = DigitalObject.new params
        digital_objects.push dobj
      end
      log "discover_objects(found #{digital_objects.count} objects)"
    end

    # If user configured pre-assembly to process a limited N of objects,
    # return the requested number of object containers.
    def pruned_containers(containers)
      j = limit_n ? limit_n - 1 : -1
      containers[0..j]
    end

    # Every object must reside in a single container: either a file or a directory.
    # Those containers are either (a) specified in a manifest or (b) discovered
    # through a pattern-based crawl of the bundle_dir.
    def object_containers
      return discover_containers_via_manifest if object_discovery[:use_manifest]
      discover_items_via_crawl(bundle_dir, object_discovery)
    end

    # Discover object containers from a manifest.
    # The relative path to the container is supplied in one of the
    # manifest columns. The column name to use is configured by the
    # user invoking the pre-assembly script.
    def discover_containers_via_manifest
      col_name = manifest_cols[:object_container]
      manifest_rows.map { |r| path_in_bundle r[col_name] }
    end

    # A method to discover object containers or stageable items.
    # Takes a root path (e.g, bundle_dir) and a discovery data structure.
    # The latter drives the two-stage discovery process:
    #   - A glob pattern to obtain a list of dirs and/or files.
    #   - A regex to filter that list.
    def discover_items_via_crawl(root, discovery_info)
      glob  = discovery_info[:glob]
      regex = Regexp.new(discovery_info[:regex]) if discovery_info[:regex]
      items = []
      dir_glob(File.join(root, glob)).each do |item|
        rel_path = relative_path root, item
        next unless regex.nil? || rel_path =~ regex
        next if discovery_info[:files_only] && File.directory?(item)
        items.push(item)
      end
      items.sort
    end

    # When the discovered object's container functions as the stageable item,
    # we adjust the value that will serve as the DigitalObject container.
    def actual_container(container)
      stageable_discovery[:use_container] ? get_base_dir(container) : container
    end

    def stageable_items_for(container)
      return [container] if stageable_discovery[:use_container]
      discover_items_via_crawl(container, stageable_discovery)
    end

    # Returns a list of the ObjectFiles for a digital object.
    def discover_object_files(stageable_items)
      object_files = []
      Array(stageable_items).each do |stageable|
        find_files_recursively(stageable).each do |file_path|
          object_files.push(new_object_file stageable, file_path)
        end
      end
      object_files
    end

    # A convenience method to return all ObjectFiles for all digital objects.
    # Also used for stubbing during testing.
    def all_object_files
      digital_objects.map { |dobj| dobj.object_files }.flatten
    end

    def new_object_file(stageable, file_path)
      ObjectFile.new(
        :path                 => file_path,
        :relative_path        => relative_path(get_base_dir(stageable), file_path),
        :exclude_from_content => exclude_from_content(file_path)
      )
    end

    # If user supplied a content exclusion regex pattern, see
    # whether it matches the current file path.
    def exclude_from_content(file_path)
      return false unless content_exclusion
      file_path =~ content_exclusion ? true : false
    end

    ####
    # Checksums.
    ####

    # Read the provider-supplied checksums_file, using its content to populate a hash of expected checksums.
    # This method works with default output from md5sum.
    def provider_checksums
      return @provider_checksums if @provider_checksums
      return @provider_checksums = {} unless checksums_file
      log "provider_checksums()"
      regex = %r{^MD5 \((.+)\) = (\w{32})$}
      @provider_checksums = read_exp_checksums.scan(regex).map { |filename, md5| [filename, md5.strip] }.to_h
    end

    # Read checksums file. Wrapped in a method for unit testing.  Normalize CR/LF to be sure regex works
    def read_exp_checksums
      IO.read(checksums_file).gsub(/\r\n?/, "\n")
    end

    # Takes a DigitalObject. For each of its ObjectFiles,
    # sets the checksum attribute.
    def load_checksums(dobj)
      log "  - load_checksums()"
      dobj.object_files.each { |file| file.checksum = retrieve_checksum(file) }
    end

    # Takes a path to a file. Returns md5 checksum, which either (a) came
    # from a provider-supplied checksums file, or (b) is computed here.
    def retrieve_checksum(file)
      provider_checksums[file.path] ||= compute_checksum(file)
    end

    def compute_checksum(file)
      @compute_checksum ? file.md5 : nil
    end

    ####
    # Object file validation.
    ####

    def validate_files(dobj)
      log "  - validate_files()"

      i = 0
      success = false
      failed_validation = false
      exception = nil
      tally = Hash.new(0) # A tally to facilitate testing.

      until i == Dor::Config.dor.num_attempts || success || failed_validation do
        i += 1
        begin
          tally = Hash.new(0) # A tally to facilitate testing.
          dobj.object_files.each do |f|
            if !f.image?
              tally[:skipped] += 1
            elsif f.valid_image? && f.has_color_profile?
              tally[:valid] += 1
            else
              msg = "File validation failed: #{f.path}"
              failed_validation = true
              raise msg
            end
          end
          success = true
        rescue Exception => e
          raise e if failed_validation # just raise the exception as normal if we have a failed file validation
          log "      ** VALIDATE_FILES FAILED **, and trying attempt #{i} of #{Dor::Config.dor.num_attempts} in #{Dor::Config.dor.sleep_time} seconds"
          exception = e
          sleep Dor::Config.dor.sleep_time
        end
      end

      if success == false && !failed_validation
        error_message = "validate_files failed after #{i} attempts \n"
        log error_message
        error_message += "exception: #{exception.message}\n"
        error_message += "backtrace: #{exception.backtrace}"
        Honeybadger.notify(exception)
        raise exception
      else
        return tally
      end
    end

    # for on object, confirm that the checksums provided match freshly computed checksums
    # @param [PreAssembly::DigitalObject] dobj
    def confirm_checksums(dobj)
      # log "  - confirm_checksums()"
      result = false
      dobj.object_files.each { |f| result = (f.md5 == provider_checksums[File.basename(f.path)]) }
      result
    end

    # confirm that the all of the source IDs supplied within a manifest are locally unique
    def manifest_sourceids_unique?
      all_source_ids = manifest_rows.collect { |r| r[manifest_cols[:source_id]] }
      all_source_ids.size == all_source_ids.uniq.size
    end

    ####
    # Manifest.
    ####

    # For bundles using a manifest, adds the manifest info to the digital objects.
    # Assumes a parallelism between the @digital_objects and manifest_rows arrays.
    def process_manifest
      return unless object_discovery[:use_manifest]
      log "process_manifest()"
      mrows = manifest_rows # Convenience variable, and used for testing.
      digital_objects.each_with_index do |dobj, i|
        r = mrows[i]
        # Get label and source_id from column names declared in YAML config.
        label_value = (manifest_cols[:label] ? r[manifest_cols[:label]] : "")
        dobj.label        = label_value
        dobj.source_id    = (r[manifest_cols[:source_id]] + source_id_suffix) if manifest_cols[:source_id]
        # Also store a hash of all values from the manifest row, using column names as keys.
        dobj.manifest_row = r
      end
    end

    # On first call, loads the manifest data (does not reload on subsequent calls).
    # If bundle is not using a manifest, just loads and returns emtpy array.
    def manifest_rows
      return @manifest_rows if @manifest_rows
      self.manifest_rows = object_discovery[:use_manifest] ? self.class.import_csv(manifest) : []
    end

    ####
    # Digital object processing.
    ####
    def process_digital_objects
      # Get the non-skipped objects to process, limited to n if the user asked for that
      o2p = pruned_containers(objects_to_process)

      total_obj = o2p.size
      num_objects_to_process = objects_to_process.size
      log "process_digital_objects(#{total_obj} objects)"
      log_and_show "#{total_obj} objects to pre-assemble"
      log_and_show("**** limit of #{limit_n} was applied after completed objects removed from set") if limit_n
      log_and_show "#{digital_objects.size} total objects found, #{num_objects_to_process} not yet complete, #{skippables.size} already completed objects skipped"

      n = 0
      num_no_file_warnings = 0
      avg_time_per_object = 0
      total_time_remaining = 0

      start_time = Time.now

      # Initialize the progress_log_file, unless we are resuming
      FileUtils.rm(progress_log_file, :force => true) unless resume

      # Start processing.
      o2p.each do |dobj|
        if throttle_time.to_i > 0
          log_and_show "sleeping for #{throttle_time.to_i} seconds"
          sleep throttle_time.to_i
        end

        log_and_show "#{total_obj - n} remaining in run | #{total_obj} running | #{num_objects_to_process - n} total incomplete | ~ remaining: #{PreAssembly::Logging.seconds_to_string(total_time_remaining)}"
        log "  - Processing object: #{dobj.unadjusted_container}"
        log "  - N object files: #{dobj.object_files.size}"
        puts "Working on '#{dobj.unadjusted_container}' containing #{dobj.object_files.size} files" if show_progress
        num_no_file_warnings += 1 if dobj.object_files.size == 0

        begin
          # Try to pre_assemble the digital object.
          load_checksums(dobj)
          validate_files(dobj) if validate_files
          dobj.reaccession = true if !accession_items.nil? && accession_items[:reaccession] # if we are reaccessioning items, then go ahead and clear each one out
          dobj.pre_assemble(desc_md_template_xml)
          # Indicate that we finished.
          dobj.pre_assem_finished = true
          log_and_show "Completed #{dobj.druid.druid}"
        rescue Exception => e
          # For now, just re-raise any exceptions.
          #
          # Later, we might decide to do the following:
          #   - catch specific types of expected exceptions
          #   - from that point, raise a PreAssembly::PreAssembleError
          #   - then catch such errors here, allowing the current
          #     digital object to fail but the remaining objects to be processed.
          Honeybadger.notify(e)
          raise e
        ensure
          # Log the outcome no matter what.
          File.open(progress_log_file, 'a') { |f| f.puts log_progress_info(dobj).to_yaml }
        end

        total_time = Time.now - start_time
        n += 1

        avg_time_per_object = total_time / n
        total_time_remaining = (avg_time_per_object * (num_objects_to_process - n)).floor
      end

      log_and_show "**WARNING**: #{num_no_file_warnings} objects had no files" if (num_no_file_warnings > 0)
      log_and_show "#{total_obj} objects pre-assembled"
    end

    def objects_to_process
      objects = digital_objects.reject { |dobj| skippables.has_key?(dobj.unadjusted_container) }
      unless accession_items.nil? # check to see if we are specifying certain objects to be accessioned
        unless accession_items[:only].nil? # handle the "only" case for accession items specified
          objects.reject! do |dobj|
            bundle_id = dobj.druid ? dobj.druid.druid : dobj.container_basename
            !accession_items[:only].include?(bundle_id)
          end
        end
        unless accession_items[:except].nil? # handle the "except" case for accession items specified
          objects.reject! do |dobj|
            bundle_id = dobj.druid ? dobj.druid.druid : dobj.container_basename
            accession_items[:except].include?(bundle_id)
          end
        end
      end
      objects
    end

    def log_progress_info(dobj)
      {
        :unadjusted_container => dobj.unadjusted_container,
        :pid                  => dobj.pid,
        :pre_assem_finished   => dobj.pre_assem_finished,
        :timestamp            => Time.now.strftime('%Y-%m-%d %H:%I:%S')
      }
    end

    def delete_digital_objects
      return unless @cleanup # FIXME: getter conflicts with defined #cleanup method (that should be named "cleanup!")
      # During development, delete objects that we register.
      log "delete_digital_objects()"
      digital_objects.each(&:unregister)
    end

    ####
    # File and directory utilities.
    ####

    def path_in_bundle(rel_path)
      File.join(bundle_dir, rel_path)
    end

    # Returns the portion of the path after the base. For example:
    #   base     BLAH/BLAH
    #   path     BLAH/BLAH/foo/bar.txt
    #   returns            foo/bar.txt
    def relative_path(base, path)
      bs = base.size
      return path[bs + 1..-1] if (
        bs > 0 &&
        path.size > bs &&
        path.index(base) == 0
      )
      err_msg = "Bad args to relative_path(#{base.inspect}, #{path.inspect})"
      raise ArgumentError, err_msg
    end

    # Returns the portion of the path before basename. For example:
    #   path     BLAH/BLAH/foo/bar.txt
    #   returns  BLAH/BLAH/foo
    def get_base_dir(path)
      bd = File.dirname(path)
      return bd unless bd == '.'
      err_msg = "Bad arg to get_base_dir(#{path.inspect})"
      raise ArgumentError, err_msg
    end

    def dir_glob(pattern)
      Dir.glob(pattern).sort
    end

    # Takes a path to a file or dir. Returns all files (but not dirs) contained in the path, recursively.
    def find_files_recursively(path)
      patterns = [path, File.join(path, '**', '*')]
      Dir.glob(patterns).reject { |f| File.directory? f }.sort
    end

    ####
    # Misc utilities.
    ####
    def entries_in_bundle_directory
      @entries_in_bundle_directory ||= Dir.entries(bundle_dir).reject { |f| f == '.' || f == '..' }
    end

    # used to add characters to the reported message and bump up an error count incremeneter
    def report_error_message(message)
      @error_count += 1
      " ** ERROR: #{message.upcase} ** ,"
    end

    def log_and_show(message)
      log message
      puts "#{Time.now}: #{message}" if show_progress
    end

    # Used during development to append a timestamp to source IDs.
    def source_id_suffix
      uniqify_source_ids ? Time.now.strftime('_%s') : ''
    end
  end
end
