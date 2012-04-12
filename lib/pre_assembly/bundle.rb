require 'csv-mapper'
require 'ostruct'

module PreAssembly

  class BundleUsageError < StandardError
    # Exception class used to pass usage error messages back to
    # users of the bin/pre-assemble script.
  end

  class Bundle
    include PreAssembly::Logging
    include CsvMapper

    attr_accessor(
      :bundle_dir,
      :manifest,
      :descriptive_metadata_template,
      :desc_metadata_xml_template,
      :checksums_file,
      :project_name,
      :apo_druid_id,
      :set_druid_id,
      :staging_dir,
      :limit_n,
      :uniqify_source_ids,
      :show_progress,
      :validate_usage,
      :user_params,
      :project_style,
      :provider_checksums,
      :publish,
      :shelve,
      :preserve,
      :digital_objects,
      :object_discovery,
      :stageable_discovery,
      :manifest_cols,
      :stager
    )


    ####
    # Initialization.
    ####

    def initialize(params = {})
      # Unpack the user-supplied parameters.
      conf   = Dor::Config.pre_assembly
      params = Bundle.symbolize_keys params

      @user_params         = params
      @project_style       = params[:project_style].to_sym
      @bundle_dir          = params[:bundle_dir]     || ''
      @staging_dir         = params[:staging_dir]
      @manifest            = params[:manifest]
      @checksums_file      = params[:checksums_file]
      @project_name        = params[:project_name]
      @apo_druid_id        = params[:apo_druid_id]
      @set_druid_id        = params[:set_druid_id]
      @publish             = params[:publish]  || conf.publish
      @shelve              = params[:shelve]   || conf.shelve
      @preserve            = params[:preserve] || conf.preserve
      @limit_n             = params[:limit_n]
      @uniqify_source_ids  = params[:uniqify_source_ids]
      @show_progress       = params[:show_progress]
      @validate_usage      = params[:validate_usage]
      @object_discovery    = params[:object_discovery]
      @stageable_discovery = params[:stageable_discovery]
      @manifest_cols       = params[:manifest_cols]

      @descriptive_metadata_template = params[:descriptive_metadata_template] || conf.descriptive_metadata_template

      # Other setup work facilitated by having access to instance vars.
      setup
    end

    def setup
      @manifest           = path_in_bundle @manifest       unless @checksums_file.nil?
      @checksums_file     = path_in_bundle @checksums_file unless @checksums_file.nil?
      @provider_checksums = {}
      @digital_objects    = []
      @manifest_rows      = nil
      @stager             = lambda { |f,d| FileUtils.copy f, d }

      @descriptive_metadata_template = path_in_bundle @descriptive_metadata_template
      @desc_metadata_xml_template    = File.open( @descriptive_metadata_template, "rb").read if file_exists @descriptive_metadata_template

      # Validate parameters supplied via user script.
      # Unit testing often bypasses such checks.
      validate_usage if @validate_usage
    end

    def attr_for_digital_objects
      # Returns a simple object containing bundle-level information that
      # will need to be passed down to DigitalObjects as they are created.
      a = OpenStruct.new
      a.project_name               = @project_name
      a.apo_druid_id               = @apo_druid_id
      a.set_druid_id               = @set_druid_id
      a.publish                    = @publish
      a.shelve                     = @shelve
      a.preserve                   = @preserve
      a.desc_metadata_xml_template = @desc_metadata_xml_template
      return a
    end


    ####
    # Usage validation.
    ####

    def required_dirs
      [@bundle_dir, @staging_dir]
    end

    def required_files
      @project_style == :style_revs ? [@manifest, @checksums_file] : []
    end

    def required_user_params
      [
        :project_style,
        :bundle_dir,
        :staging_dir,
        :manifest,
        :checksums_file,
        :project_name,
        :apo_druid_id,
        :set_druid_id,
      ]
    end

    def validate_usage
      # Check for required parameters, directories, and files.
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

    def run_pre_assembly
      # TODO: run_pre_assembly: allow non-Revs projects to run.
      log ""
      log "run_pre_assembly(#{run_log_msg})"
      if @project_style == :style_revs

        # New steps.
        discover_objects
        load_checksums
        process_manifest
        validate_files
        process_digital_objects
        return

        # Old Revs-centric steps. Will delete soon.
        load_provider_checksums
        load_manifest
        validate_images
        process_digital_objects
        return

      else
        # Not ready for prime-time.
      end
    end

    def run_log_msg
      log_params = {
        :project_style => @project_style,
        :bundle_dir    => @bundle_dir,
        :staging_dir   => @staging_dir,
        :environment   => ENV['ROBOT_ENVIRONMENT'],
      }
      return log_params.map { |k,v| "#{k}='#{v}'"  }.join(', ')
    end


    ####
    # Discovery of object containers and stageable items.
    ####

    def discover_objects
      # Discovers the digital object containers and the stageable items within them.
      # For each container, create a new Digitalobject.
      bundle_attr = attr_for_digital_objects
      use_c       = @stageable_discovery[:use_container]
      pruned_containers(object_containers).each do |c|
        # If using the container as the stageable item,
        # the DigitalObject container is just the bundle_dir.
        container  = use_c ? @bundle_dir : path_in_bundle(c)
        stageables = stageable_items_for(c)
        files      = discover_all_files(stageables)
        # Create the object.
        params = {
          :container       => container,
          :stageable_items => stageables,
          :object_files    => files.map { |f| new_object_file(f) },
          :bundle_attr     => bundle_attr,
        }
        dobj = DigitalObject.new params
        @digital_objects.push dobj
      end
    end

    def pruned_containers(containers)
      # If user configured pre-assembly to process a limited N of objects,
      # return the requested number.
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
      return items
    end

    def stageable_items_for(container)
      return [container] if @stageable_discovery[:use_container]
      return discover_items_via_crawl(container, @stageable_discovery)
    end

    def discover_all_files(stageable_items)
      # Returns a list of the files for a digital object.
      # This list differs from stageable_items only when some
      # of the stageable_items are directories.
      return stageable_items.map { |i| find_files_recursively i }.flatten
    end

    def all_object_files
      # A convenience method to return all ObjectFiles for all digital objects.
      # Also used for stubbing during testing.
      @digital_objects.map { |dobj| dobj.object_files }.flatten
    end

    def new_object_file(file_path)
      return ObjectFile.new(
        :path          => file_path,
        :relative_path => relative_path(@bundle_dir, file_path)
      )
    end


    ####
    # Checksums.
    ####

    def load_checksums
      load_provider_checksums if @checksums_file
      all_object_files.each do |file|
        file.checksum = retrieve_checksum(file.path)
      end
    end

    def load_provider_checksums
      # Read checksums_file, using its content to populate a hash of expected checksums.
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

    def retrieve_checksum(file_path)
      # Takes a path to a file. Returns md5 checksum, which either (a) comes
      # from a provider-supplied checksums file, or (b) is computed here.
      @provider_checksums[file_path] ||= compute_checksum(file_path)
    end

    def compute_checksum(file_path)
      return Checksum::Tools.new({}, :md5).digest_file(file_path)[:md5]
    end
      

    ####
    # Manifest.
    ####

    def process_manifest
      # For bundles using a manifest, adds the manifest info to the digital objects.
      # Assumes a parallelism between the @digital_objects and @manifest_rows arrays.
      return unless @object_discovery[:use_manifest]
      mrows = manifest_rows  # Convenience variable, and used for testing.
      @digital_objects.each_with_index do |dobj, i|
        r                  = mrows[i]
        dobj.label         = r.label
        dobj.source_id     = r.sourceid + source_id_suffix
        dobj.manifest_attr = Hash[r.each_pair.to_a]
      end
    end

    def manifest_rows
      # On first call, loads the manifest data (does not reload on subsequent calls).
      # If bundles is not using a manifest, just loads and returns emtpy array.
      return @manifest_rows if @manifest_rows
      @manifest_rows = @object_discovery[:use_manifest] ? load_manifest_rows_from_csv : []
    end

    def load_manifest_rows_from_csv
      # Wrap the functionality provided by csv-mapper.
      return import(@manifest) { read_attributes_from_file }
    end

    def load_manifest
      # Read manifest and initialize digital objects.
      log "load_manifest()"
      manifest_rows.each do |r|
        # Create digital object.
        dobj_params = {
          :project_name => @project_name,
          :apo_druid_id => @apo_druid_id,
          :set_druid_id => @set_druid_id,
          :desc_metadata_xml_template => @desc_metadata_xml_template,
          :publish      => @publish,
          :shelve       => @shelve,
          :preserve     => @preserve,
          :source_id    => r.sourceid + source_id_suffix,
          :label        => r.label,
        }
        dobj = DigitalObject::new dobj_params

        # Add the image to the object.
        f = r.filename
        dobj.add_image(
          :file_name     => f,
          :full_path     => path_in_bundle(f),
          :provider_attr => Hash[r.each_pair.to_a],
          :exp_md5       => @provider_checksums[f]
        )
        @digital_objects.push dobj

        # Bail if user asked to process a limited N of objects.
        break if @limit_n and @digital_objects.size >= @limit_n
      end
    end


    ####
    # Digital object processing.
    ####

    def validate_files
      tally = Hash.new(0)           # A tally to facilitate testing.
      all_object_files.each do |f|
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

    def validate_images
      log "validate_images()"
      @digital_objects.each do |dobj|
        dobj.images.each do |img|
          next if img.valid?
          msg = "Image validation failed: #{img.full_path} #{dobj.source_id.inspect}"
          raise msg
        end
      end
    end

    def process_digital_objects
      log "process_digital_objects()"
      @digital_objects.each do |dobj|
        dobj.pre_assemble(@stager, @staging_dir)
        puts dobj.druid.druid if @show_progress 
      end
    end


    ####
    # File and directory utilities.
    ####

    def path_in_bundle(rel_path)
      File.join @bundle_dir, rel_path
    end

    def relative_path(base, path)
      # Takes a base and a path. Return the portion of the path after the base:
      #   base     BLAH/BLAH
      #   path     BLAH/BLAH/foo/bar.txt
      #   returns            foo/bar.txt
      path[base.size + 1 .. -1]
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
      patterns = [path, "#{path}/**/*"]
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

  end

end
