# frozen_string_literal: true

module PreAssembly
  class Batch
    include PreAssembly::Logging

    attr_reader :batch_context
    attr_writer :digital_objects
    attr_accessor :error_message,
                  :file_manifest,
                  :objects_had_errors,
                  :skippables,
                  :user_params

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
        environment: Rails.env
      }
      log_params.map { |k, v| "#{k}=#{v.inspect}" }.join(', ')
    end

    def object_filenames_unique?(dobj)
      filenames = dobj.object_files.map { |objfile| File.basename(objfile.path) }
      filenames.count == filenames.uniq.count
    end

    # Discovers the digital object containers and the stageable items within them.
    # For each container, creates a new Digitalobject.
    # @return [Array<DigitalObject>]
    # rubocop:disable Metrics/AbcSize
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
    # rubocop:enable Metrics/AbcSize

    # For each of the passed DigitalObject's ObjectFiles, sets the checksum attribute.
    # @param [DigitalObject] dobj
    def load_checksums(dobj)
      log '  - load_checksums()'
      dobj.object_files.each { |file| file.provider_md5 = file.md5 }
    end

    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/CyclomaticComplexity
    def process_digital_objects
      num_no_file_warnings = 0
      num_failures = 0
      errors = []
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
        file_attributes_supplied = batch_context.all_files_public? || dobj.dark?
        load_checksums(dobj)
        progress = dobj.pre_assemble(file_attributes_supplied)
        progress.merge!(pid: dobj.pid, container: dobj.container, timestamp: Time.now.utc.strftime('%Y-%m-%d %H:%M:%S'))
        num_failures += 1 if progress[:status] == 'error'
        log "Completed #{dobj.druid}"
        File.open(progress_log_file, 'a') { |f| f.puts progress.to_yaml }
      end
      errors << "#{num_no_file_warnings} objects had no files" if num_no_file_warnings > 0
      errors << "#{num_failures} objects had errors during pre-assembly" if num_failures > 0
      errors.each { |error| log "**WARNING**: #{error}" }
      @objects_had_errors = !errors.size.zero? # indicate if we had any errors
      @error_message = errors.join(', ') # set the error message so they can be saved in the job_run

      log "#{total_obj} objects pre-assembled"
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/CyclomaticComplexity

    # @return [Array<DigitalObject>]
    def objects_to_process
      @objects_to_process ||= digital_objects.reject { |dobj| skippables.key?(dobj.container) }
    end

    private

    def stager
      staging_style_symlink ? LinkStager : CopyStager
    end

    # Discover object containers from the object manifest file suppled in the bundle_dir.
    def discover_containers_via_manifest
      manifest_rows.each_with_index do |r, i|
        next if r[:object]
        raise 'Missing header row in manifest.csv' if i == 0

        raise "Missing 'object' in row #{i}: #{r}"
      end
      manifest_rows.map { |r| bundle_dir_with_path r[:object] }
    end

    # A method to discover stageable items (i.e. files) with a given object folder.
    # Takes a root path of the object folder (as supplied in the object manifest).
    # It then finds all files within with an eager glob pattern.
    def discover_items_via_crawl(root)
      Dir.glob("#{root}/**/*")
    end

    # A convenience method to return all ObjectFiles for all digital objects.
    # Also used for stubbing during testing.
    def all_object_files
      digital_objects.map(&:object_files).flatten
    end

    # @return [Boolean] - true if object access is dark, false otherwise
    def dark?(druid)
      dobj = object_client(druid).find
      dobj.access.view == 'dark'
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
  end
end
