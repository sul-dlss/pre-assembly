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
    ]

    OTHER_ACCESSORS = [
      :user_params,
      :provider_checksums,
      :digital_objects,
      :desc_md_template_xml,
      :progress_log_handle,
    ]

    (YAML_PARAMS + OTHER_ACCESSORS).each { |p| attr_accessor p }


    ####
    # Initialization.
    ####

    def initialize(params = {})
      # Unpack the user-supplied parameters, after converting
      # all hash keys and some hash values to symbols.
      conf   = Dor::Config.pre_assembly
      params = Bundle.symbolize_keys params
      Bundle.values_to_symbols! params[:project_style]
      @user_params = params
      YAML_PARAMS.each { |p| instance_variable_set "@#{p.to_s}", params[p] }

      # Other setup work.
      setup_paths
      setup_other
      validate_usage
      load_desc_md_template
    end

    def setup_paths
      @manifest         = path_in_bundle @manifest         unless @manifest.nil?
      @checksums_file   = path_in_bundle @checksums_file   unless @checksums_file.nil?
      @desc_md_template = path_in_bundle @desc_md_template unless @desc_md_template.nil?
    end

    def setup_other
      @provider_checksums  = {}
      @digital_objects     = []
      @manifest_rows       = nil
      @content_exclusion   = Regexp.new(@content_exclusion) if @content_exclusion
      @progress_log_handle = nil
      @publish_attr.delete_if { |k,v| v.nil? }
    end

    def load_desc_md_template
      return nil unless @desc_md_template and file_exists(@desc_md_template)
      @desc_md_template_xml = IO.read(@desc_md_template)
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


    ####
    # The main process.
    ####

    # Runs a confirmation for each digital object and confirms there are no duplicate filenames contained within the object
    # This is useful if you will be flattening the folder structure during pre-assembly.
    def confirm_object_filenames_unique
      log ""
      log "confirm_object_filenames_unique(#{run_log_msg})"
      unique_objects=0
      File.open(@progress_log_file, 'w') do |@progress_log_handle|
        discover_objects
        @digital_objects.each do |dobj|
           bundle_id=dobj.druid ? dobj.druid.druid : dobj.container_basename
           is_unique=object_filenames_unique? dobj
           unique_objects+=1 if is_unique
           puts "#{bundle_id} has duplicate filenames" if @show_progress && !is_unique
        end
      end
      puts "Total objects with non unique filenames: #{@digital_objects.count - unique_objects}" if @show_progress
      return processed_pids      
    end
    
    def run_pre_assembly
      # Runs the pre-assembly process and returns an array of PIDs
      # of the digital objects processed.
      log ""
      log "run_pre_assembly(#{run_log_msg})"
      File.open(@progress_log_file, 'w') do |@progress_log_handle|
        discover_objects
        load_provider_checksums
        process_manifest

        load_checksums
        validate_files
        process_digital_objects
        delete_digital_objects
      end
      return processed_pids
    end

    def run_log_msg
      log_params = {
        :project_style => @project_style,
        :bundle_dir    => @bundle_dir,
        :staging_dir   => @staging_dir,
        :environment   => ENV['ROBOT_ENVIRONMENT'],
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
      puts "Discovered #{@digital_objects.count} digital objects" if @show_progress
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
      regex   = Regexp.new discovery_info[:regex]
      pattern = File.join root, glob
      items   = []
      dir_glob(pattern).each do |item|
        rel_path = relative_path root, item
        items.push(item) if rel_path =~ regex
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

    def load_checksums
      log "load_checksums()"
      all_object_files.each do |file|
        file.checksum = retrieve_checksum(file.path)
      end
    end

    def load_provider_checksums
      # Read the provider-supplied checksums_file, using its 
      # content to populate a hash of expected checksums.
      # This method works with default output from md5sum.
      return unless @checksums_file
      log "  - load_provider_checksums()"
      checksum_regex = %r{^MD5 \((.+)\) = (\w{32})$}
      read_exp_checksums.scan(checksum_regex).each { |file_name, md5|
        @provider_checksums[file_name] = md5
      }
    end

    def read_exp_checksums
      # Read checksums file. Wrapped in a method for unit testing.
      IO.read @checksums_file
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

    def validate_files
      log "validate_files()"
      puts "validating files" if @show_progress
      tally = Hash.new(0)           # A tally to facilitate testing.
      all_object_files.each do |f|
        if not f.image?
          tally[:skipped] += 1
          puts "#{f.path} is not an image" if @show_progress
        elsif f.valid_image?
          tally[:valid] += 1
          puts "#{f.path} is a valid image" if @show_progress
        else
          msg = "File validation failed: #{f.path}"
          raise msg
        end
      end
      return tally
    end

    def process_digital_objects
      log "process_digital_objects()"
      puts "processing objects" if @show_progress
      
      @digital_objects.each do |dobj|
        begin
          # Try to pre_assemble the digital object.
          dobj.pre_assemble
          # Indicate that we finished.
          dobj.pre_assem_finished = true
          puts dobj.druid.druid if @show_progress
        rescue
          # For now, just re-raise the exception.
          #
          # Later, we might decide to do the following:
          #   - catch specific types of exceptions in DigitalObject during the
          #     pre_assemble() process
          #   - from that point, raise a PreAssembly::PreAssembleError
          #   - then catch such errors here, allowing the current
          #     digital object to fail but the remaining objects to be processed.
          raise
        ensure
          # Log the outcome no matter what.
          log_progress(dobj)
        end
      end
    end

    def log_progress(dobj)
      info = {
        :unadjusted_container => dobj.unadjusted_container,
        :pid                  => dobj.pid,
        :pre_assem_finished   => dobj.pre_assem_finished,
      }
      @progress_log_handle.puts info.to_yaml
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
