# frozen_string_literal: true

module PreAssembly
  # theoretically contains code common to both discovery reports and pre-assemble runs
  #   both job types need to process the digital objects determined from the batch_context and
  #   indicated either by a file_manifest.csv, or by walking the directory with the object data to be used.
  class Batch
    include PreAssembly::Logging

    attr_reader :batch_context
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
      @objects_had_errors = false # will be set to true if we discover any errors when running pre-assembly
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
    # For each container, creates a new PreAssembly::Digitalobject.
    # @return [Enumerable<PreAssembly::DigitalObject>]
    # @yield [PreAssembly::DigitalObject]
    # rubocop:disable Metrics/AbcSize
    def digital_objects(&_block)
      return enum_for(:digital_objects) { containers_via_manifest.size } unless block_given?

      containers_via_manifest.each_with_index.map do |container, i|
        stageable_items = discover_items_via_crawl(container)
        row = manifest_rows[i]
        dark = dark?(row[:druid])
        yield DigitalObject.new(self,
                                container: container,
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

    # any objects that have not yet been run successfully through a pre-assembly job (used by both pre-assembly and discovery reports)
    # @return [Enumerable<PreAssembly::DigitalObject>]
    # @yield [PreAssembly::DigitalObject]
    def un_pre_assembled_objects(&block)
      return enum_for(:un_pre_assembled_objects) { digital_objects.size } unless block_given?

      digital_objects.lazy.reject { |dobj| pre_assembled_object_containers&.key?(dobj.container) }.each { |dobj| block.call(dobj) }
    end

    private

    def stager
      staging_style_symlink ? LinkStager : CopyStager
    end

    # any objects that have already been run successfully through a pre-assembly job
    def pre_assembled_object_containers
      @pre_assembled_object_containers ||= begin
        pre_assembled_object_containers = {}

        if File.readable?(progress_log_file)
          docs = YAML.load_stream(File.read(progress_log_file))
          docs = docs.documents if docs.respond_to? :documents
          docs.each do |yd|
            pre_assembled_object_containers[yd[:container]] = true if yd[:pre_assem_finished]
          end
          pre_assembled_object_containers
        end
      end
    end

    # Discover object containers from the object manifest file suppled in the bundle_dir.
    # @return [Enumerable<String>]
    # @yield [String]
    def containers_via_manifest(&block)
      return enum_for(:containers_via_manifest) { manifest_rows.size } unless block_given?

      manifest_rows.each_with_index do |manifest_row, i|
        next if manifest_row[:object]

        raise "Missing 'object' in row #{i}: #{manifest_row}"
      end

      manifest_rows.map { |manifest_row| bundle_dir_with_path manifest_row[:object] }.each { |manifest_row| block.call(manifest_row) }
    end

    # A method to discover stageable items (i.e. files) with a given object folder.
    # Takes a root path of the object folder (as supplied in the object manifest).
    # It then finds all files within with an eager glob pattern.
    def discover_items_via_crawl(root)
      Dir.glob("#{root}/**/*")
    end

    # ignores objects already pre-assembled as part of re-runnability of preassembly job
    # rubocop:disable Metrics/AbcSize
    def pre_assemble_objects
      @num_failures = 0
      @num_no_file_warnings = 0
      log "pre_assemble_objects(#{num_to_pre_assemble} objects)"
      log "#{num_to_pre_assemble} objects to pre-assemble"
      log "#{digital_objects.size} total objects found, #{pre_assembled_object_containers&.size} already completed objects skipped"

      pre_assemble_each_object # ignores objects already pre-assembled

      log "**WARNING: #{num_no_file_warnings} objects had no files" if num_no_file_warnings > 0
      if num_failures > 0
        @objects_had_errors = true
        @error_message = "#{num_failures} objects had errors during pre-assembly" # error message that will be saved in the job run
        log "**WARNING**: #{@error_message}"
      end
      log "#{num_to_pre_assemble} objects pre-assembled"
    end
    # rubocop:enable Metrics/AbcSize

    # pre-assemble each object that hasn't been pre-assembled already
    # rubocop:disable Metrics/AbcSize
    def pre_assemble_each_object
      un_pre_assembled_objects.each_with_index do |dobj, i|
        log "#{num_to_pre_assemble - i} remaining in run | #{num_to_pre_assemble} running"
        log "  - Processing object: #{dobj.container}"
        log "  - N object files: #{dobj.object_files.size}"
        @num_no_file_warnings += 1 if dobj.object_files.empty?
        file_attributes_supplied = batch_context.all_files_public? || dobj.dark?
        load_checksums(dobj)
        progress = dobj.pre_assemble(file_attributes_supplied)
        log "  - pre_assemble result: #{progress}"
        progress.merge!(pid: dobj.pid, container: dobj.container, timestamp: Time.now.utc.strftime('%Y-%m-%d %H:%M:%S'))
        @num_failures += 1 if progress[:status] == 'error'
        log "Completed #{dobj.druid}"
        File.open(progress_log_file, 'a') { |f| f.puts progress.to_yaml }
      end
    end
    # rubocop:enable Metrics/AbcSize

    def num_to_pre_assemble
      @num_to_pre_assemble ||= un_pre_assembled_objects.size
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
    # @param [PreAssembly::DigitalObject] dobj
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
