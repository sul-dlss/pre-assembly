require 'csv-mapper'

module PreAssembly

  class BundleUsageError < StandardError
    # An exception class used to pass usage error messages
    # back to users of the bin/pre-assemble script.
  end

  class Bundle

    include PreAssembly::Logging
    include CsvMapper

    # Paramaters passed via YAML config files.
    YAML_PARAMS = [
      :project_style,
      :bundle_dir,
      :staging_dir,
      :reaccession_items,
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
    ]

    OTHER_ACCESSORS = [
      :user_params,
      :provider_checksums,
      :digital_objects,
      :skippables,
      :desc_md_template_xml
    ]

    (YAML_PARAMS + OTHER_ACCESSORS).each { |p| attr_accessor p }
    
    ####
    # Initialization.
    ####

    def initialize(params = {})
      # Unpack the user-supplied parameters, after converting
      # all hash keys and some hash values to symbols.
      params = Bundle.symbolize_keys params
      Bundle.values_to_symbols! params[:project_style]
      cmc          = params[:content_md_creation]
      cmc[:style]  = cmc[:style].to_sym
      @user_params = params
      YAML_PARAMS.each { |p| instance_variable_set "@#{p.to_s}", params[p] }

      # Other setup work.
      setup_paths
      setup_other
      validate_usage
      load_desc_md_template
      load_skippables
    end

    def setup_paths
      @manifest         = path_in_bundle @manifest         unless @manifest.nil?
      @checksums_file   = path_in_bundle @checksums_file   unless @checksums_file.nil?
      @desc_md_template = path_in_bundle @desc_md_template unless @desc_md_template.nil?
      @staging_dir = Dor::Config.pre_assembly.assembly_workspace if @staging_dir.nil? # if the user didn't supply a bundle_dir, use the default
    end

    def setup_other
      @provider_checksums  = {}
      @digital_objects     = []
      @skippables          = {}
      @manifest_rows       = nil
      @content_exclusion   = Regexp.new(@content_exclusion) if @content_exclusion
      @publish_attr.delete_if { |k,v| v.nil? }
    end

    def load_desc_md_template
      return nil unless @desc_md_template and file_exists(@desc_md_template)
      @desc_md_template_xml = IO.read(@desc_md_template)
    end

    def load_skippables
      return unless @resume
      YAML.each_document(PreAssembly::Utils.read_file(@progress_log_file)) do |yd|
        skippables[yd[:unadjusted_container]] = true if yd[:pre_assem_finished]
      end
    end

    ####
    # Usage validation.
    ####

    def required_dirs
      [@bundle_dir, @staging_dir]
    end

    def required_files
      # If a file parameter from the YAML is non-nil, the file must exist.
      [@manifest, @checksums_file, @desc_md_template].compact
    end

    def required_user_params
      return YAML_PARAMS
    end

    def validate_usage
      # Validate parameters supplied via user script.
      # Unit testing often bypasses such checks.
      return unless @validate_usage

      required_user_params.each do |p|
        next if @user_params.has_key? p
        raise BundleUsageError, "Missing parameter: #{p}."
      end

      required_dirs.each do |d|
        next if dir_exists d
        raise BundleUsageError, "Required directory not found: #{d}."
      end

      required_files.each do |f|
        next if file_exists f
        raise BundleUsageError, "Required file not found: #{f}."
      end
    end


    def discovery_report
      # Runs a confirmation for each digital object and confirms there are 
      # no duplicate filenames contained within the object. This is useful
      # if you will be flattening the folder structure during pre-assembly.
      log ""
      log "discovery_report(#{run_log_msg})"
      puts "\nProject : #{@project_name}"
      puts "Directory : #{@bundle_dir}"
      puts "NOTE: You appear to be using a manifest file - this method is not very useful" if @manifest
      puts "\nObject Container : Number of Items"
      unique_objects=0
      entries_in_bundle_directory=Dir.entries(@bundle_dir).reject {|f| f=='.' || f=='..'}
      total_entries_in_bundle_directory=entries_in_bundle_directory.count
      discover_objects
      objects_in_bundle_directory=@digital_objects.collect {|dobj| dobj.container_basename}
      total_objects=@digital_objects.size
      @digital_objects.each do |dobj|
         bundle_id=dobj.druid ? dobj.druid.druid : dobj.container_basename
         is_unique=object_filenames_unique? dobj
         unique_objects+=1 if is_unique
         message="#{bundle_id} : #{dobj.object_files.count}"
         message += ": Duplicate filenames!" if !is_unique
         puts message
      end
      puts "\nTotal Discovered Objects: #{total_objects}"
      puts "Total Files and Folders in bundle directory: #{total_entries_in_bundle_directory}"
      if total_entries_in_bundle_directory != total_objects
        puts "List of entries in bundle directory that will not be discovered: " 
        puts (entries_in_bundle_directory - objects_in_bundle_directory).join("\n")
      end
      puts "\nObjects with non unique filenames: #{total_objects - unique_objects}"
      return processed_pids      
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

    ####
    # Cleanup of objects and associated files in specified environment using logfile as input
    ####
    def cleanup(steps=[],dry_run=false)

      log "cleanup()"
      PreAssembly::Utils.cleanup(:druids=>PreAssembly::Utils.get_completed_druids_from_log(@progress_log_file),:steps=>steps,:dry_run=>dry_run)
            
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
      @compute_checksum ? Checksum::Tools.new({}, :md5).digest_file(file_path)[:md5] : nil
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
        dobj.label         = r.send(@manifest_cols[:label])
        dobj.source_id     = r.send(@manifest_cols[:source_id]) + source_id_suffix
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
      puts "#{o2p.size} objects to Pre-Assemble" if @show_progress
      
      # Initialize the progress_log_file, unless we are resuming
      FileUtils.rm(@progress_log_file, :force => true) unless @resume

      # Start processing.
      o2p.each do |dobj|
        log "  - Processing object: #{dobj.unadjusted_container}"
        log "  - N object files: #{dobj.object_files.size}"
        puts "Working on '#{dobj.unadjusted_container}' containing #{dobj.object_files.size} files" if @show_progress
        
        begin
          # Try to pre_assemble the digital object.
          load_checksums(dobj)
          validate_files(dobj)
          dobj.reaccession=true if @reaccession_items # if we are reaccessioning items, then go ahead and clear each one out
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

      end
    end

    def objects_to_process
      objects=@digital_objects.reject { |dobj| @skippables.has_key?(dobj.unadjusted_container) }
      unless @reaccession_items.nil?
        objects.reject! do |dobj|
           bundle_id=dobj.druid ? dobj.druid.druid : dobj.container_basename 
          !@reaccession_items.include?(bundle_id)
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

    def dir_exists(dir)
      File.directory? dir
    end

    def file_exists(file)
      File.exists? file
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

    def source_id_suffix
      # Used during development to append a timestamp to source IDs.
      @uniqify_source_ids ? Time.now.strftime('_%s') : ''
    end

    def self.symbolize_keys(h)
      # Takes a data structure and recursively converts all hash keys
      # from strings to symbols.
      if h.instance_of? Hash
        h.inject({}) { |hh,(k,v)| hh[k.to_sym] = symbolize_keys(v); hh }
      elsif h.instance_of? Array
        h.map { |v| symbolize_keys(v) }
      else
        h
      end
    end

    def self.values_to_symbols!(h)
      # Takes a hash and converts its string values to symbols -- not recursively.
      h.each { |k,v| h[k] = v.to_sym if v.class == String }
    end
    
  end

end
