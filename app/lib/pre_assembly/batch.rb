# frozen_string_literal: true

module PreAssembly
  class Batch
    include PreAssembly::Logging

    attr_reader :batch_context
    attr_writer :digital_objects
    attr_accessor :user_params,
                  :skippables,
                  :file_manifest

    delegate :apo_druid_id,
             :apply_tag,
             :bundle_dir,
             :config_filename,
             :content_md_creation,
             :content_structure,
             :manifest_rows,
             :bundle_dir_with_path,
             :progress_log_file,
             :project_name,
             :set_druid_id,
             :stageable_discovery,
             :staging_style_symlink,
             :using_file_manifest,
             to: :batch_context

    def initialize(batch_context)
      @batch_context = batch_context
      self.file_manifest = PreAssembly::FileManifest.new(csv_filename: batch_context.file_manifest, bundle_dir: bundle_dir) if batch_context.using_file_manifest
      self.skippables = {}
      load_skippables
    end

    def load_skippables
      return unless File.readable?(progress_log_file)
      docs = YAML.load_stream(File.read(progress_log_file))
      docs = docs.documents if docs.respond_to? :documents
      docs.each do |yd|
        skippables[yd[:container]] = true if yd[:pre_assem_finished]
      end
    end

    # Runs the pre-assembly process
    # @return [void]
    def run_pre_assembly
      log "\nstarting run_pre_assembly(#{run_log_msg})"
      process_digital_objects
      log "\nfinishing run_pre_assembly(#{run_log_msg})"
    end

    def run_log_msg
      log_params = {
        content_structure: content_structure,
        project_name: project_name,
        bundle_dir: bundle_dir,
        assembly_staging_dir: Settings.assembly_staging_dir,
        environment: ENV['RAILS_ENV']
      }
      log_params.map { |k, v| "#{k}=#{v.inspect}" }.join(', ')
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
        stageable_items = discover_items_via_crawl(c)
        row = manifest_rows[i]
        dark = dark?(row[:druid])
        DigitalObject.new(self,
                          container: c,
                          stageable_items: stageable_items,
                          object_files: ObjectFileFinder.run(stageable_items: stageable_items, druid: row[:druid], dark: dark, all_files_public: batch_context.all_files_public?),
                          label: row.fetch('label', ''),
                          source_id: row['sourceid'],
                          pid: row[:druid],
                          stager: stager,
                          dark: dark)
      end
    end

    # For each of the passed DigitalObject's ObjectFiles, sets the checksum attribute.
    # @param [DigitalObject] dobj
    def load_checksums(dobj)
      log '  - load_checksums()'
      dobj.object_files.each { |file| file.provider_md5 = file.md5 }
    end

    ####
    # Digital object processing.
    ####
    def process_digital_objects
      num_no_file_warnings = 0
      # Get the non-skipped objects to process
      total_obj = objects_to_process.size
      log "process_digital_objects(#{total_obj} objects)"
      log "#{total_obj} objects to pre-assemble"
      log "#{digital_objects.size} total objects found, #{skippables.size} already completed objects skipped"

      objects_to_process.each_with_index do |dobj, n|
        log "#{total_obj - n} remaining in run | #{total_obj} running"
        log "  - Processing object: #{dobj.container}"
        log "  - N object files: #{dobj.object_files.size}"
        num_no_file_warnings += 1 if dobj.object_files.empty?
        progress = { dobj: dobj }
        file_attributes_supplied = batch_context.all_files_public? || dobj.dark?
        begin
          # Try to pre_assemble the digital object.
          load_checksums(dobj)
          status = dobj.pre_assemble(file_attributes_supplied)
          # Indicate that we finished.
          progress[:pre_assem_finished] = true
          log "Completed #{dobj.druid}"
        ensure
          # Log the outcome no matter what.
          File.open(progress_log_file, 'a') { |f| f.puts log_progress_info(progress, status || incomplete_status).to_yaml }
        end
      end
    ensure
      log "**WARNING**: #{num_no_file_warnings} objects had no files" if num_no_file_warnings > 0
      log "#{total_obj || 0} objects pre-assembled"
    end

    # @return [Array<DigitalObject>]
    def objects_to_process
      @objects_to_process ||= digital_objects.reject { |dobj| skippables.key?(dobj.container) }
    end

    def log_progress_info(info, status)
      status = incomplete_status unless status&.any?
      {
        container: info[:dobj].container,
        pid: info[:dobj].pid,
        pre_assem_finished: info[:pre_assem_finished],
        timestamp: Time.now.strftime('%Y-%m-%d %H:%M:%S')
      }.merge(status)
    end

    private

    def stager
      staging_style_symlink ? LinkStager : CopyStager
    end

    def incomplete_status
      { status: 'error', message: 'pre_assemble did not complete' }
    end

    # Discover object containers from a manifest.
    # The relative path to the container is supplied in one of the
    # manifest columns. The column name to use is configured by the
    # user invoking the pre-assembly script.
    def discover_containers_via_manifest
      manifest_rows.each_with_index { |r, i| raise "Missing 'object' in row #{i}: #{r}" unless r[:object] }
      manifest_rows.map { |r| bundle_dir_with_path r[:object] }
    end

    # A method to discover object containers or stageable items.
    # Takes a root path (e.g, bundle_dir) and a discovery data structure.
    # The latter drives the two-stage discovery process:
    #   - A glob pattern to obtain a list of dirs and/or files.
    #   - A regex to filter that list.
    # FIXME: configuration of aforementioned stageable_discovery data structure is currently unsupported.
    # the remnants are vestiges of v3-legacy branch that we didn't have time to properly disposition.
    # behavior should either be fully removed, or properly reimplemented and tested.
    # see: #274, https://github.com/sul-dlss/pre-assembly/blob/v3-legacy/config/projects/TEMPLATE.yaml
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

    # A convenience method to return all ObjectFiles for all digital objects.
    # Also used for stubbing during testing.
    def all_object_files
      digital_objects.map(&:object_files).flatten
    end

    # @return [Boolean] - true if object access is dark, false otherwise
    def dark?(druid)
      dobj = object_client(druid).find
      dobj.access.access == 'dark'
    rescue Dor::Services::Client::NotFoundResponse
      { item_not_registered: true }
    rescue RuntimeError # HTTP timeout, network error, whatever
      { dor_connection_error: true }
    end

    def object_client(druid)
      d = druid
      d = "druid:#{d}" unless d.start_with?('druid:')
      @object_client ||= Dor::Services::Client.object(d)
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

    def dir_glob(pattern)
      Dir.glob(pattern).sort
    end
  end
end
