# encoding: UTF-8

require 'ostruct'
require 'pathname'

module PreAssembly
  class Bundle
    include PreAssembly::Logging
    include PreAssembly::Reporting

    attr_reader :bundle_context
    attr_writer :digital_objects
    attr_accessor :user_params,
                  :skippables,
                  :smpl_manifest

    delegate :accession_items,
             :apo_druid_id,
             :apply_tag,
             :bundle_dir,
             :config_filename,
             :content_exclusion,
             :content_md_creation,
             :content_structure,
             :file_attr,
             :manifest_cols,
             :manifest_rows,
             :path_in_bundle,
             :progress_log_file,
             :project_name,
             :set_druid_id,
             :stageable_discovery,
             :assembly_staging_dir,
             :staging_style_symlink,
             :validate_files?,
           to: :bundle_context

    def initialize(bundle_context)
      @bundle_context = bundle_context
      self.skippables = {}
      load_skippables
    end

    def load_skippables
      return unless File.readable?(progress_log_file)
      docs = YAML.load_stream(IO.read(progress_log_file))
      docs = docs.documents if docs.respond_to? :documents
      docs.each do |yd|
        skippables[yd[:unadjusted_container]] = true if yd[:pre_assem_finished]
      end
    end

    ####
    # The main process.
    ####

    # Runs the pre-assembly process and returns an array of PIDs of the digital objects processed.
    def run_pre_assembly
      log ""
      log "run_pre_assembly(#{run_log_msg})"
      puts "#{Time.now}: Pre-assembly started for #{project_name}"

      # load up the SMPL manifest if we are using that style
      if bundle_context.smpl_cm_style?
        self.smpl_manifest = PreAssembly::Smpl.new(:csv_filename => bundle_context.smpl_manifest, :bundle_dir => bundle_dir)
      end
      process_digital_objects
      puts "#{Time.now}: Pre-assembly completed for #{project_name}"
      processed_pids
    end

    def run_log_msg
      log_params = {
        :content_structure => content_structure,
        :project_name => project_name,
        :bundle_dir => bundle_dir,
        :assembly_staging_dir => Settings.assembly_staging_dir,
        :environment => ENV['RAILS_ENV'],
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

    ####
    # Discovery of object containers and stageable items.
    #
    # Discovers the digital object containers and the stageable items within them.
    # For each container, creates a new Digitalobject.
    # @return [Array<DigitalObject>]
    def digital_objects
      @digital_objects ||= discover_containers_via_manifest.each_with_index.map do |c, i|
        params = digital_object_base_params.merge(
          :container            => c,
          :stageable_items      => discover_items_via_crawl(c),
          :unadjusted_container => c
        )
        params[:object_files] = discover_object_files(params[:stageable_items])
        DigitalObject.new(params).tap do |dobj|
          r = manifest_rows[i]
          # Get label and source_id from column names declared in YAML config.
          dobj.label        = manifest_cols[:label] ? r[manifest_cols[:label]] : ""
          dobj.source_id    = r[manifest_cols[:source_id]] if manifest_cols[:source_id]
          # Also store a hash of all values from the manifest row, using column names as keys.
          dobj.manifest_row = r
        end
      end
    end

    def digital_object_base_params
      {
        :bundle_dir           => bundle_dir,
        :content_md_creation  => content_md_creation,
        :file_attr            => file_attr,
        :project_name         => project_name,
        :project_style        => content_structure,
        :smpl_manifest        => smpl_manifest,
        :assembly_staging_dir => assembly_staging_dir,
        :staging_style        => staging_style_symlink
      }
    end

    # Discover object containers from a manifest.
    # The relative path to the container is supplied in one of the
    # manifest columns. The column name to use is configured by the
    # user invoking the pre-assembly script.
    def discover_containers_via_manifest
      raise RuntimeError, ':manifest_cols must be specified' unless manifest_cols
      col_name = manifest_cols[:object_container].to_sym
      raise RuntimeError, "object_container must be specified in manifest_cols: #{manifest_cols}" unless col_name
      manifest_rows.each_with_index { |r, i| raise "Missing #{col_name} in row #{i}: #{r}" unless r[col_name] }
      manifest_rows.map { |r| path_in_bundle r[col_name] }
    end

    # A method to discover object containers or stageable items.
    # Takes a root path (e.g, bundle_dir) and a discovery data structure.
    # The latter drives the two-stage discovery process:
    #   - A glob pattern to obtain a list of dirs and/or files.
    #   - A regex to filter that list.
    def discover_items_via_crawl(root)
      glob  = stageable_discovery[:glob] || '**/*' # default value
      regex = Regexp.new(stageable_discovery[:regex]) if stageable_discovery[:regex]
      items = []
      dir_glob(File.join(root, glob)).each do |item|
        rel_path = relative_path(root, item)
        next if regex && rel_path !~ regex
        next if stageable_discovery[:files_only] && File.directory?(item)
        items.push(item)
      end
      items.sort
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

    # Takes a DigitalObject. For each of its ObjectFiles,
    # sets the checksum attribute.
    def load_checksums(dobj)
      log "  - load_checksums()"
      dobj.object_files.each { |file| file.checksum = file.md5 }
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

      # TODO: clarify (peter might know?) - seems this is essentially a retry loop, where validation failure is fatal,
      # but other things (like... fedora connection error?) allow for another attempt until max num_attempts.
      until i == Dor::Config.dor_services.num_attempts || success || failed_validation do
        i += 1
        begin
          tally = Hash.new(0) # A tally to facilitate testing.
          dobj.object_files.each do |f|
            if !f.image?
              tally[:skipped] += 1
            elsif f.valid_image? && f.has_color_profile?
              tally[:valid] += 1
            else
              failed_validation = true
              raise "File validation failed: #{f.path}"
            end
          end
          success = true
        rescue Exception => e
          raise e if failed_validation # just raise the exception as normal if we have a failed file validation
          log "      ** VALIDATE_FILES FAILED **, and trying attempt #{i} of #{Dor::Config.dor_services.num_attempts} in #{Dor::Config.dor_services.sleep_time} seconds"
          exception = e
          sleep Dor::Config.dor_services.sleep_time
        end
      end

      # TODO: goes w/ above question - wasn't able to set success to true, didn't fail validation, so... some
      # other unexpected problem?
      if success == false && !failed_validation
        error_message = "validate_files failed after #{i} attempts \n"
        log error_message
        error_message += "exception: #{exception.message}\n"
        error_message += "backtrace: #{exception.backtrace}"
        # TODO: would bet the intent was to pass in error_message, since it includes
        # exception, and the modifications to it are thrown away as it is.
        Honeybadger.notify(exception)
        raise exception
      else
        return tally
      end
    end

    # confirm that the all of the source IDs supplied within a manifest are locally unique
    def manifest_sourceids_unique?
      all_source_ids = manifest_rows.collect { |r| r[manifest_cols[:source_id]] }
      all_source_ids.size == all_source_ids.uniq.size
    end

    ####
    # Digital object processing.
    ####
    def process_digital_objects
      # Get the non-skipped objects to process
      o2p = objects_to_process
      total_obj = o2p.size
      log "process_digital_objects(#{total_obj} objects)"
      log_and_show "#{total_obj} objects to pre-assemble"
      log_and_show "#{digital_objects.size} total objects found, #{skippables.size} already completed objects skipped"
      num_no_file_warnings = 0
      total_time_remaining = 0
      start_time = Time.now

      # Start processing.
      o2p.each_with_index do |dobj, n|
        log_and_show "#{total_obj - n} remaining in run | #{total_obj} running | ~ remaining: #{PreAssembly::Logging.seconds_to_string(total_time_remaining)}"
        log "  - Processing object: #{dobj.unadjusted_container}"
        log "  - N object files: #{dobj.object_files.size}"
        puts "Working on '#{dobj.unadjusted_container}' containing #{dobj.object_files.size} files"
        num_no_file_warnings += 1 if dobj.object_files.size == 0

        begin
          # Try to pre_assemble the digital object.
          load_checksums(dobj)
          validate_files(dobj) if validate_files?
          dobj.pre_assemble
          # Indicate that we finished.
          dobj.pre_assem_finished = true
          log_and_show "Completed #{dobj.druid}"
        rescue Exception => e
          # For now, just re-raise any exceptions.
          #
          # Later, we might decide to do the following:
          #   - catch specific types of expected exceptions
          #   - from that point, raise a PreAssembly::PreAssembleError
          #   - then catch such errors here, allowing the current
          #     digital object to fail but the remaining objects to be processed.
          Honeybadger.notify(e) # ??? Isn't this what Honeybadger would do anyway w/o the rescue?
          raise e
        ensure
          # Log the outcome no matter what.
          File.open(progress_log_file, 'a') { |f| f.puts log_progress_info(dobj).to_yaml }
        end

        next_n = n + 1
        avg_time_per_object = (Time.now - start_time) / next_n
        total_time_remaining = (avg_time_per_object * (total_obj - next_n)).floor
      end

      log_and_show "**WARNING**: #{num_no_file_warnings} objects had no files" if (num_no_file_warnings > 0)
      log_and_show "#{total_obj} objects pre-assembled"
    end

    def objects_to_process
      return @o2p if @o2p
      @o2p = digital_objects.reject { |dobj| skippables.has_key?(dobj.unadjusted_container) }
      return @o2p if accession_items.nil? # check to see if we are specifying certain objects to be accessioned
      if accession_items[:only]
        whitelist = accession_items[:only].map { |x| DruidTools::Druid.new(x).druid } # normalize
        @o2p.select! { |dobj| whitelist.include?(dobj.druid.druid) }
      end
      if accession_items[:except]
        blacklist = accession_items[:except].map { |x| DruidTools::Druid.new(x).druid } # normalize
        @o2p.reject! { |dobj| blacklist.include?(dobj.druid.druid) }
      end
      @o2p
    end

    def log_progress_info(dobj)
      {
        :unadjusted_container => dobj.unadjusted_container,
        :pid                  => dobj.pid,
        :pre_assem_finished   => dobj.pre_assem_finished,
        :timestamp            => Time.now.strftime('%Y-%m-%d %H:%I:%S')
      }
    end

    ####
    # File and directory utilities.
    ####

    # @return [String] base
    # @return [String] path
    # @return [String] portion of the path after the base, without trailing slashes (if directory)
    # @example Usage
    #   b.relative_path('BLAH/BLAH', 'BLAH/BLAH/foo/bar.txt'
    #   => 'foo/bar.txt'
    #   b.relative_path('BLAH/BLAH', 'BLAH/BLAH/foo///'
    #   => 'foo'
    def relative_path(base, path)
      Pathname.new(path).relative_path_from(Pathname.new(base)).cleanpath.to_s
    end

    # @return [String] path
    # @return [String] directory portion of the path before basename
    # @example Usage
    #   b.get_base_dir('BLAH/BLAH/foo/bar.txt')
    #   => 'BLAH/BLAH/foo'
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
      puts "#{Time.now}: #{message}"
    end
  end
end
