require 'csv-mapper'

module PreAssembly

  class BundleUsageError < StandardError
    # An exception class used to pass usage error messages
    # back to users of the bin/pre-assemble script.
  end

  class Bundle

    include CsvMapper
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
      :apo_druid_id,
      :set_druid_id,
      :publish_attr,
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
      :validate_files
    ]

    OTHER_ACCESSORS = [
      :user_params,
      :provider_checksums,
      :digital_objects,
      :skippables,
      :desc_md_template_xml    ]

    (YAML_PARAMS + OTHER_ACCESSORS).each { |p| attr_accessor p }
    
    ####
    # Initialization.
    ####

    def initialize(params = {})
      # Unpack the user-supplied parameters, after converting
      # all hash keys and some hash values to symbols.
      params = Assembly::Utils.symbolize_keys params
      Assembly::Utils.values_to_symbols! params[:project_style]
      cmc          = params[:content_md_creation]
      cmc[:style]  = cmc[:style].to_sym
      @user_params = params
      YAML_PARAMS.each { |p| instance_variable_set "@#{p.to_s}", params[p] }

      # Other setup work.
      setup_paths
      setup_other
      validate_usage
      show_developer_setting_warning
      load_desc_md_template
      load_skippables
      
    end

    def setup_paths
      @manifest         = path_in_bundle @manifest         unless @manifest.nil?
      @checksums_file   = path_in_bundle @checksums_file   unless @checksums_file.nil?
      @desc_md_template = path_in_bundle @desc_md_template unless @desc_md_template.nil?
      @staging_dir = Assembly::ASSEMBLY_WORKSPACE if @staging_dir.nil? # if the user didn't supply a bundle_dir, use the default
      @progress_log_file = File.join(File.dirname(@config_filename),File.basename(@config_filename,'.yaml') + '_progress.yaml') if @progress_log_file.nil? # if the user didn't supply a progress log file, use the yaml config file as a base, and add '_progress'
    end

    def setup_other
      @provider_checksums  = {}
      @digital_objects     = []
      @skippables          = {}
      @manifest_rows       = nil
      @content_exclusion   = Regexp.new(@content_exclusion) if @content_exclusion
      @publish_attr={} if @publish_attr.nil?
      @publish_attr.delete_if { |k,v| v.nil? }
      @validate_files = true if @validate_files.nil? # default to validating files if not provided
    end

    def load_desc_md_template
      return nil unless @desc_md_template and File.readable?(@desc_md_template)
      @desc_md_template_xml = IO.read(@desc_md_template)
    end

    def load_skippables
      return unless @resume
      YAML.each_document(Assembly::Utils.read_file(@progress_log_file)) do |yd|
        skippables[yd[:unadjusted_container]] = true if yd[:pre_assem_finished]
      end
    end

    ####
    # Usage validation.
    ####

    # allowed controlled vocabulary for various configuration paramaters
    def allowed_values
      {
        :project_style=>{
          :content_structure=>[:simple_image,:simple_book,:book_as_image,:smpl],
          :get_druid_from=>[:suri,:container,:container_barcode,:manifest,:druid_minter],
          },
        :content_md_creation=>{
          :style=>[:default,:joined,:smpl],
        }
      }  
    end
    
    def required_dirs
      [@bundle_dir, @staging_dir]
    end

    def required_files
      # If a file parameter from the YAML is non-nil, the file must exist.
      [@manifest, @checksums_file, @desc_md_template].compact
    end

    def required_user_params
      YAML_PARAMS-non_required_user_params
    end
    
    def non_required_user_params
      [:config_filename,:validate_files]
    end
    
    def show_developer_setting_warning
      # spit out some dire warning messages if you set certain parameters that are only applicable for developers
      warning=[]
      warning<<'* get_druid_from=druid_minter' if @project_style[:get_druid_from]==:druid_minter
      warning<<'* init_assembly_wf=false' unless @init_assembly_wf
      warning<<'* uniqify_source_ids=true' if @uniqify_source_ids             
      warning<<'* cleanup=true' if @cleanup
      puts "\n***DEVELOPER MODE WARNING: You have set some parameters typically only set by developers****\n#{warning.join("\n")}" if @show_progress && warning.size > 0
    end
    
    def validate_usage
      # Validate parameters supplied via user script.
      # Unit testing often bypasses such checks.
      return unless @validate_usage

      validation_errors=[]
      
      required_user_params.each do |p|
        next if @user_params.has_key? p
        validation_errors << "Missing parameter: #{p}."
      end

      required_dirs.each do |d|
        next if File.directory? d
        validation_errors <<  "Required directory not found: #{d}."
      end

      required_files.each do |f|
        next if File.readable? f
        validation_errors <<  "Required file not found: #{f}."
      end

      validation_errors <<  "Staging directory '#{@staging_dir}' not writable." unless File.writable?(@staging_dir)
      validation_errors <<  "Progress log file '#{@progress_log_file}' or directory not writable." unless File.writable?(File.dirname(@progress_log_file)) 

      if @project_style[:should_register] # if should_register=true, check some stuff
        validation_errors << "The APO DRUID must be set if should_register = true." if @apo_druid_id.blank? #APO can't be blank
        validation_errors << "get_druid_from: 'manifest' is only valid if should_register = false." if @project_style[:get_druid_from]==:manifest # can't use manifest to get druid if not yet registered
        validation_errors << "If should_register=true, then you must use a manifest." unless @object_discovery[:use_manifest] # you have to use a manifest if you want to register objects
      else  # if should_register=false, check some stuff
        if @project_style[:get_druid_from] != :container_barcode
          validation_errors << "The APO and SET DRUIDs should not be set if should_register = false." if (@apo_druid_id || @set_druid_id)  # APO and SET should not be set
        else
          validation_errors << "The APO DRUID must be set if project_style:get_druid_from = container_barcode." if @apo_druid_id.blank? # APO DRUID must be added for container_barcode projects
          validation_errors << "The SET DRUID should not be set if project_style:get_druid_from = container_barcode." if @set_druid_id # SET DRUID must not be set for container_barcode projects
        end
        validation_errors << "get_druid_from: 'suri' is only valid if should_register = true." if @project_style[:get_druid_from]==:suri # can't use SURI to get druid
        validation_errors << "get_druid_from: 'manifest' is only valid if use_manifest = true." if @project_style[:get_druid_from]==:manifest && @object_discovery[:use_manifest] == false # can't use SURI to get druid
      end
      
      
      if @object_discovery[:use_manifest] # if we are using a manifest, check some stuff 
        validation_errors << "The glob and regex for object_discovery should not be set if object_discovery:use_manifest=true." unless @object_discovery[:glob].nil? && @object_discovery[:regex].nil? # glob and regex should be nil
         if @manifest.blank?
           validation_errors << "A manifest file must be provided if object_discovery:use_manifest=true." # you need a manifest file!
         else # let's see if the columns the user claims are there exist in the actual manifest
           validation_errors << "Manifest does not have a column called '#{@manifest_cols[:object_container]}'" unless manifest_rows.first.methods.include? @manifest_cols[:object_container]
           validation_errors << "You must define a label and source_id column in the manifest if should_register=true" if (@manifest_cols[:source_id].blank? || @manifest_cols[:label].blank?) && @project_style[:should_register] # if this is a project with should_register=true, we always need a source ID and a label column
           validation_errors << "Manifest does not have a column called '#{@manifest_cols[:source_id]}'" if !@manifest_cols[:source_id].blank? && !manifest_rows.first.methods.include?(@manifest_cols[:source_id])
           validation_errors << "Manifest does not have a column called '#{@manifest_cols[:label]}'" if !@manifest_cols[:label].blank? && !manifest_rows.first.methods.include?(@manifest_cols[:label])
           validation_errors << "You must have a column labeled 'druid' in your manifest if you want to use project_style:get_druid_from=manifest" if @project_style[:get_druid_from]==:manifest && !manifest_rows.first.methods.include?('druid')
         end        
      else # if we are not using a manifest, check some stuff
        validation_errors << "The glob for object_discovery must be set if object_discovery:use_manifest=false." if @object_discovery[:glob].blank? # glob must be set
        validation_errors << "Manifest and desc_md_template files should be set to nil if object_discovery:use_manifest=false." unless @manifest.blank? && @desc_md_template.blank?
      end

      if @stageable_discovery[:use_container] # if we are staging the whole container, check some stuff
        validation_errors <<  "If stageable_discovery:use_container=true, you cannot use get_druid_from='container'." if @project_style[:get_druid_from].to_s =~ /^container/ # if you are staging the entire container, it doesn't make sense to use the container to get the druid
      else # if we are not staging the whole container, check some stuff
        validation_errors << "If stageable_discovery:use_container=false, you must set a glob to discover files in each container." if @stageable_discovery[:glob].blank? # glob must be set
      end
      
       # check parameters that are part of a controlled vocabulary to be sure they don't have bogus values
       validation_errors << "The project_style:content_structure value of '#{@project_style[:content_structure]}' is not valid." unless allowed_values[:project_style][:content_structure].include? @project_style[:content_structure]
       validation_errors << "The project_style:get_druid_from value of '#{@project_style[:get_druid_from]}' is not valid." unless allowed_values[:project_style][:get_druid_from].include? @project_style[:get_druid_from]
       validation_errors << "The content_md_creation:style value of '#{@content_md_creation[:style]}' is not valid." unless allowed_values[:content_md_creation][:style].include? @content_md_creation[:style]
      
      if !validation_errors.blank?
        validation_errors = ['Configuration errors found:'] + validation_errors
        raise BundleUsageError, validation_errors.join('  ') if !validation_errors.blank?
      end
      
    end
    
    ####
    # The main process.
    ####
    
    def run_pre_assembly
      # Runs the pre-assembly process and returns an array of PIDs
      # of the digital objects processed.
      log ""
      log "run_pre_assembly(#{run_log_msg})"
      discover_objects
      load_provider_checksums
      process_manifest
      process_digital_objects
      delete_digital_objects
      return processed_pids
    end

    def run_log_msg
      log_params = {
        :project_style => @project_style,
        :bundle_dir    => @bundle_dir,
        :staging_dir   => @staging_dir,
        :environment   => ENV['ROBOT_ENVIRONMENT'],
        :resume        => @resume,
      }
      return log_params.map { |k,v| "#{k}=#{v.inspect}"  }.join(', ')
    end

    def processed_pids
      return @digital_objects.map { |dobj| dobj.pid }
    end

    def object_filenames_unique?(dobj)
      filenames = dobj.object_files.map {|objfile| File.basename(objfile.path) } 
      filenames.count == filenames.uniq.count
    end

    def object_files_exist?(dobj)
      if dobj.object_files.size == 0 
        return false
      else
        all_files_exist = dobj.object_files.map {|objfile| File.readable?(objfile.path)} 
        return !all_files_exist.uniq.include?(false)
      end
    end

    ####
    # Cleanup of objects and associated files in specified environment using logfile as input
    ####
    def cleanup(steps=[],dry_run=false)

      log "cleanup()"
      if File.exists?(@progress_log_file)
        druids=Assembly::Utils.get_druids_from_log(@progress_log_file)
      else
        puts "#{@progress_log_file} not found!  Cannot proceed"
        return
      end
      Assembly::Utils.cleanup(:druids=>druids,:steps=>steps,:dry_run=>dry_run)
    end

    ####
    # Discovery of object containers and stageable items.
    ####
    
    def discover_objects
      # Discovers the digital object containers and the stageable items within them.
      # For each container, creates a new Digitalobject.
      log "discover_objects()"
      pruned_containers(object_containers).each do |c|
        container    = actual_container(c)
        stageables   = stageable_items_for(c)
        object_files = discover_object_files(stageables)
        params = {
          :project_style        => @project_style,
          :bundle_dir           => @bundle_dir,
          :staging_dir          => @staging_dir,
          :desc_md_template_xml => @desc_md_template_xml,
          :project_name         => @project_name,
          :apo_druid_id         => @apo_druid_id,
          :set_druid_id         => @set_druid_id,
          :publish_attr         => @publish_attr,
          :init_assembly_wf     => @init_assembly_wf,
          :content_md_creation  => @content_md_creation,
          :container            => container,
          :unadjusted_container => c,
          :stageable_items      => stageables,
          :object_files         => object_files,
        }
        dobj = DigitalObject.new params
        @digital_objects.push dobj
      end
      log "discover_objects(found #{@digital_objects.count} objects)"
    end

    def pruned_containers(containers)
      # If user configured pre-assembly to process a limited N of objects,
      # return the requested number of object containers.
      j = @limit_n ? @limit_n - 1 : -1
      containers[0 .. j]
    end

    def object_containers
      # Every object must reside in a single container: either a file or a directory.
      # Those containers are either (a) specified in a manifest or (b) discovered
      # through a pattern-based crawl of the bundle_dir.
      if @object_discovery[:use_manifest]
        return discover_containers_via_manifest
      else
        return discover_items_via_crawl @bundle_dir, @object_discovery
      end
    end

    def discover_containers_via_manifest
      # Discover object containers from a manifest.
      # The relative path to the container is supplied in one of the
      # manifest columns. The column name to use is configured by the
      # user invoking the pre-assembly script.
      col_name = @manifest_cols[:object_container]
      return manifest_rows.map { |r| path_in_bundle r.send(col_name) }
    end

    def discover_items_via_crawl(root, discovery_info)
      # A method to discover object containers or stageable items.
      # Takes a root path (e.g, bundle_dir) and a discovery data structure.
      # The latter drives the two-stage discovery process:
      #   - A glob pattern to obtain a list of dirs and/or files.
      #   - A regex to filter that list.
      glob    = discovery_info[:glob]
      regex   = Regexp.new(discovery_info[:regex]) if discovery_info[:regex]
      pattern = File.join root, glob
      items   = []
      dir_glob(pattern).each do |item|
        rel_path = relative_path root, item
        items.push(item) if regex.nil? or rel_path =~ regex
      end
      return items.sort
    end

    def actual_container(container)
      # When the discovered object's container functions as the stageable item,
      # we adjust the value that will serve as the DigitalObject container.
      return @stageable_discovery[:use_container] ? get_base_dir(container) : container
    end

    def stageable_items_for(container)
      return [container] if @stageable_discovery[:use_container]
      return discover_items_via_crawl(container, @stageable_discovery)
    end

    def discover_object_files(stageable_items)
      # Returns a list of the ObjectFiles for a digital object.
      object_files = []
      stageable_items.each do |stageable|
        find_files_recursively(stageable).each do |file_path|
          object_files.push(new_object_file stageable, file_path)
        end
      end
      return object_files
    end

    def all_object_files
      # A convenience method to return all ObjectFiles for all digital objects.
      # Also used for stubbing during testing.
      @digital_objects.map { |dobj| dobj.object_files }.flatten
    end

    def new_object_file(stageable, file_path)
      return ObjectFile.new(
        :path                 => file_path,
        :relative_path        => relative_path(get_base_dir(stageable), file_path),
        :exclude_from_content => exclude_from_content(file_path)
      )
    end

    def exclude_from_content(file_path)
      # If user supplied a content exclusion regex pattern, see
      # whether it matches the current file path.
      return false unless @content_exclusion
      return file_path =~ @content_exclusion ? true : false
    end


    ####
    # Checksums.
    ####

    def load_provider_checksums
      # Read the provider-supplied checksums_file, using its 
      # content to populate a hash of expected checksums.
      # This method works with default output from md5sum.
      return unless @checksums_file
      log "load_provider_checksums()"
      checksum_regex = %r{^MD5 \((.+)\) = (\w{32})$}
      read_exp_checksums.scan(checksum_regex).each { |file_name, md5|
        @provider_checksums[file_name] = md5
      }
    end

    def read_exp_checksums
      # Read checksums file. Wrapped in a method for unit testing.
      IO.read @checksums_file
    end

    def load_checksums(dobj)
      # Takes a DigitalObject. For each of its ObjectFiles,
      # sets the checksum attribute.
      log "  - load_checksums()"
      dobj.object_files.each do |file|
        file.checksum = retrieve_checksum(file.path)
      end
    end

    def retrieve_checksum(file_path)
      # Takes a path to a file. Returns md5 checksum, which either (a) came
      # from a provider-supplied checksums file, or (b) is computed here.
      @provider_checksums[file_path] ||= compute_checksum(file_path)
    end

    def compute_checksum(file_path)
      @compute_checksum ? md5(file_path) : nil
    end
    
    def md5(file_path)
      Checksum::Tools.new({}, :md5).digest_file(file_path)[:md5]  
    end
    

    ####
    # Object file validation.
    ####

    def validate_files(dobj)
      log "  - validate_files()"
      tally = Hash.new(0)           # A tally to facilitate testing.
      dobj.object_files.each do |f|
        if not f.image?
          tally[:skipped] += 1
        elsif f.valid_image?
          tally[:valid] += 1
        else
          msg = "File validation failed: #{f.path}"
          raise msg
        end
      end
      return tally
    end

    # confirm that the checksums provided match the checksums as computed 
    def confirm_checksums(dobj)
      log "  - confirm_checksums()"
      result=false
      dobj.object_files.each { |f| result=(md5(f.path) == @provider_checksums[File.basename(f.path)]) }
      return result
    end

    def manifest_sourceids_unique?
      all_source_ids=manifest_rows.collect {|r| r.send(@manifest_cols[:source_id])}
      all_source_ids.size == all_source_ids.uniq.size
    end
    
    ####
    # Manifest.
    ####

    def process_manifest
      # For bundles using a manifest, adds the manifest info to the digital objects.
      # Assumes a parallelism between the @digital_objects and @manifest_rows arrays.
      return unless @object_discovery[:use_manifest]
      log "process_manifest()"
      mrows = manifest_rows  # Convenience variable, and used for testing.
      @digital_objects.each_with_index do |dobj, i|
        r                  = mrows[i]
        # Get label and source_id from column names declared in YAML config.
        dobj.label         = r.send(@manifest_cols[:label]) if @manifest_cols[:label]
        dobj.source_id     = (r.send(@manifest_cols[:source_id]) + source_id_suffix) if @manifest_cols[:source_id] 
        # Also store a hash of all values from the manifest row, using column names as keys.
        dobj.manifest_row  = Hash[r.each_pair.to_a]
      end
    end

    def manifest_rows
      # On first call, loads the manifest data (does not reload on subsequent calls).
      # If bundle is not using a manifest, just loads and returns emtpy array.
      return @manifest_rows if @manifest_rows
      @manifest_rows = @object_discovery[:use_manifest] ? load_manifest_rows_from_csv : []
    end

    def load_manifest_rows_from_csv
      # Wrap the functionality provided by csv-mapper.
      return import(@manifest) { read_attributes_from_file }
    end


    ####
    # Digital object processing.
    ####

    def process_digital_objects
      # Get the non-skipped objects to process.
      o2p = objects_to_process
      
      log "process_digital_objects(#{o2p.size} non-skipped objects)"
      puts "#{o2p.size} objects to pre-assemble" if @show_progress
      
      n=0
      
      # Initialize the progress_log_file, unless we are resuming
      FileUtils.rm(@progress_log_file, :force => true) unless @resume

      # Start processing.
      o2p.each do |dobj|
        log "  - Processing object: #{dobj.unadjusted_container}"
        log "  - N object files: #{dobj.object_files.size}"
        puts "#{o2p.size-n} objects left" if @show_progress
        puts "Working on '#{dobj.unadjusted_container}' containing #{dobj.object_files.size} files" if @show_progress
        
        begin
          # Try to pre_assemble the digital object.
          load_checksums(dobj)
          validate_files(dobj) if @validate_files
          dobj.reaccession=true if !@accession_items.nil? && @accession_items[:reaccession] # if we are reaccessioning items, then go ahead and clear each one out
          dobj.pre_assemble
          # Indicate that we finished.
          dobj.pre_assem_finished = true
          puts "Completed #{dobj.druid.druid}" if @show_progress

        rescue
          # For now, just re-raise any exceptions.
          #
          # Later, we might decide to do the following:
          #   - catch specific types of expected exceptions
          #   - from that point, raise a PreAssembly::PreAssembleError
          #   - then catch such errors here, allowing the current
          #     digital object to fail but the remaining objects to be processed.
          raise

        ensure
          # Log the outcome no matter what.
          File.open(@progress_log_file, 'a') do |f|
            f.puts log_progress_info(dobj).to_yaml
          end
        end
        n+=1
      end
    end

    def objects_to_process
      objects=@digital_objects.reject { |dobj| @skippables.has_key?(dobj.unadjusted_container) }
      unless @accession_items.nil? # check to see if we are specifying certain objects to be accessioned
        unless @accession_items[:only].nil? # handle the "only" case for accession items specified
          objects.reject! do |dobj|
             bundle_id=dobj.druid ? dobj.druid.druid : dobj.container_basename 
             !@accession_items[:only].include?(bundle_id)
          end 
        end
        unless @accession_items[:except].nil? # handle the "except" case for accession items specified
          objects.reject! do |dobj|
             bundle_id=dobj.druid ? dobj.druid.druid : dobj.container_basename 
             @accession_items[:except].include?(bundle_id)
          end
        end 
      end
      return objects
    end

    def log_progress_info(dobj)
      return {
        :unadjusted_container => dobj.unadjusted_container,
        :pid                  => dobj.pid,
        :pre_assem_finished   => dobj.pre_assem_finished,
        :timestamp            => Time.now.to_s
      }
    end

    def delete_digital_objects
      # During development, delete objects that we register.
      log "delete_digital_objects()"
      return unless @cleanup
      @digital_objects.each { |dobj| dobj.unregister }
    end


    ####
    # File and directory utilities.
    ####

    def path_in_bundle(rel_path)
      File.join @bundle_dir, rel_path
    end

    def relative_path(base, path)
      # Returns the portion of the path after the base. For example:
      #   base     BLAH/BLAH
      #   path     BLAH/BLAH/foo/bar.txt
      #   returns            foo/bar.txt
      bs = base.size
      return path[bs + 1 .. -1] if (
        bs > 0 and 
        path.size > bs and
        path.index(base) == 0
      )
      err_msg = "Bad args to relative_path(#{base.inspect}, #{path.inspect})"
      raise ArgumentError, err_msg
    end

    def get_base_dir(path)
      # Returns the portion of the path before basename. For example:
      #   path     BLAH/BLAH/foo/bar.txt
      #   returns  BLAH/BLAH/foo
      bd = File.dirname(path)
      return bd unless bd == '.'
      err_msg = "Bad arg to get_base_dir(#{path.inspect})"
      raise ArgumentError, err_msg
    end

    def dir_glob(pattern)
      return Dir.glob pattern
    end

    def find_files_recursively(path)
      # Takes a path to a file or dir. Returns all files (but not dirs)
      # contained in the path, recursively.
      patterns = [path, File.join(path, '**', '*')]
      return Dir.glob(patterns).reject { |f| File.directory? f }
    end


    ####
    # Misc utilities.
    ####
    def entries_in_bundle_directory
      @entries_in_bundle_directory || Dir.entries(@bundle_dir).reject {|f| f=='.' || f=='..'}
    end
    
    # used to add characters to the reported message and bump up an error count incremeneter
    def report_error_message(message)
      @error_count+=1
      "** #{message.upcase} ** ,"
    end
    
    def source_id_suffix
      # Used during development to append a timestamp to source IDs.
      @uniqify_source_ids ? Time.now.strftime('_%s') : ''
    end
    
  end

end
