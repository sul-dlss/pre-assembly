# frozen_string_literal: true

module PreAssembly
  # theoretically contains code common to both discovery reports and pre-assemble runs
  #   both job types need to process the digital objects determined from the batch_context and
  #   indicated either by a file_manifest.csv, or by walking the directory with the object data to be used.
  class Batch
    include PreAssembly::Logging

    attr_reader :batch_context
    attr_writer :digital_objects
    attr_accessor :error_message,
                  :file_manifest,
                  :num_failures,
                  :num_no_file_warnings,
                  :objects_had_errors

    delegate :bundle_dir,
             :content_md_creation,
             :content_structure,
             :manifest_rows,
             :bundle_dir_with_path,
             :progress_log_file,
             :project_name,
             :staging_style_symlink,
             :using_file_manifest,
             to: :batch_context

    def initialize(batch_context)
      @batch_context = batch_context
      @file_manifest = PreAssembly::FileManifest.new(csv_filename: batch_context.file_manifest, bundle_dir: bundle_dir) if batch_context.using_file_manifest
    end

    # Runs the pre-assembly process
    # @return [void]
    def run_pre_assembly
      log "\nstarting run_pre_assembly(#{info_for_log})"
      pre_assemble_objects
      log "\nfinishing run_pre_assembly(#{info_for_log})"
    end

    # used by discovery report
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

    # used by discovery report
    # @return [Array<DigitalObject>]
    def objects_to_process
      @objects_to_process ||= digital_objects.reject { |dobj| skippables&.key?(dobj.container) }
    end

    private

    def stager
      staging_style_symlink ? LinkStager : CopyStager
    end

    # object containers that should be skipped
    def skippables
      @skippables ||= begin
        skippables = {}

        if File.readable?(progress_log_file)
          docs = YAML.load_stream(File.read(progress_log_file))
          docs = docs.documents if docs.respond_to? :documents
          docs.each do |yd|
            skippables[yd[:container]] = true if yd[:pre_assem_finished]
          end
          skippables
        end
      end
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

    # rubocop:disable Metrics/AbcSize
    def pre_assemble_objects
      @num_failures = 0
      @num_no_file_warnings = 0
      errors = []
      log "pre_assemble_objects(#{num_to_process} objects)"
      log "#{num_to_process} objects to pre-assemble"
      log "#{digital_objects.size} total objects found, #{skippables&.size} already completed objects skipped"

      pre_assemble_each_object # ignores skippable objects

      errors << "#{num_no_file_warnings} objects had no files" if num_no_file_warnings > 0
      errors << "#{num_failures} objects had errors during pre-assembly" if num_failures > 0
      errors.each { |error| log "**WARNING**: #{error}" }
      @objects_had_errors = !errors.size.zero?
      @error_message = errors.join(', ') # error message will be saved in the job_run

      log "#{num_to_process} objects pre-assembled"
    end
    # rubocop:enable Metrics/AbcSize

    # pre assemble each non-skipped object
    # rubocop:disable Metrics/AbcSize
    def pre_assemble_each_object
      objects_to_process.each_with_index do |dobj, n|
        log "#{num_to_process - n} remaining in run | #{num_to_process} running"
        log "  - Processing object: #{dobj.container}"
        log "  - N object files: #{dobj.object_files.size}"
        @num_no_file_warnings += 1 if dobj.object_files.empty?
        file_attributes_supplied = batch_context.all_files_public? || dobj.dark?
        load_checksums(dobj)
        progress = dobj.pre_assemble(file_attributes_supplied)
        progress.merge!(pid: dobj.pid, container: dobj.container, timestamp: Time.now.utc.strftime('%Y-%m-%d %H:%M:%S'))
        @num_failures += 1 if progress[:status] == 'error'
        log "Completed #{dobj.druid}"
        File.open(progress_log_file, 'a') { |f| f.puts progress.to_yaml }
      end
    end
    # rubocop:enable Metrics/AbcSize

    def num_to_process
      @num_to_process ||= objects_to_process.size
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

    # For each of the passed DigitalObject's ObjectFiles, sets the checksum attribute.
    # @param [DigitalObject] dobj
    def load_checksums(dobj)
      log '  - load_checksums()'
      dobj.object_files.each { |file| file.provider_md5 = file.md5 }
    end

    def info_for_log
      log_params = {
        content_structure: content_structure,
        project_name: project_name,
        bundle_dir: bundle_dir,
        assembly_staging_dir: Settings.assembly_staging_dir,
        environment: Rails.env
      }
      log_params.map { |k, v| "#{k}=#{v.inspect}" }.join(', ')
    end

    def object_client(druid)
      d = druid
      d = "druid:#{d}" unless d.start_with?('druid:')
      @object_client ||= Dor::Services::Client.object(d)
    end
  end
end
