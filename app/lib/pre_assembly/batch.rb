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

    delegate :staging_location,
             :content_md_creation,
             :content_structure,
             :object_manifest_rows,
             :staging_location_with_path,
             :progress_log_file,
             :project_name,
             :staging_style_symlink,
             to: :batch_context

    def initialize(batch_context, file_manifest: nil)
      @batch_context = batch_context
      @file_manifest = file_manifest
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

    # used by discovery report
    def object_filepaths_unique?(dobj)
      filepaths = dobj.object_files.map(&:path)
      filepaths.each { |fp| log fp }
      filepaths.count == filepaths.uniq.count
    end

    # Discovers the digital object containers and the stageable items within them.
    # For each container, creates a new PreAssembly::Digitalobject.
    # @return [Enumerable<PreAssembly::DigitalObject>]
    # @yield [PreAssembly::DigitalObject]
    # rubocop:disable Metrics/AbcSize
    def digital_objects
      return enum_for(:digital_objects) { containers_via_manifest.size } unless block_given?

      containers_via_manifest.map.with_index do |container, i|
        stageable_items = discover_items_via_crawl(container)
        common_path = Assembly::ObjectFile.common_path(stageable_items) # find common paths to all files provided
        row = object_manifest_rows[i]
        yield DigitalObject.new(self,
                                container: container,
                                stageable_items: stageable_items,
                                object_files: stageable_items.map { |item| PreAssembly::ObjectFile.new(item, { relative_path: item.gsub(common_path, '') }) },
                                label: row.fetch('label', ''),
                                source_id: row['sourceid'],
                                pid: row[:druid],
                                stager: stager)
      end
    end

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

    # Discover object containers from the object manifest file suppled in the staging_location.
    # @return [Enumerable<String>]
    # @yield [String]
    def containers_via_manifest(&block)
      return enum_for(:containers_via_manifest) { object_manifest_rows.size } unless block_given?

      object_manifest_rows.each.with_index(1) do |manifest_row, i|
        next if manifest_row[:object]

        raise "Missing 'object' in row #{i}: #{manifest_row}"
      end

      object_manifest_rows.map { |manifest_row| staging_location_with_path manifest_row[:object] }.each { |manifest_row| block.call(manifest_row) }
    end

    # A method to discover stageable items (i.e. files) with a given object folder.
    # Takes a root path of the object folder (as supplied in the object manifest).
    # It then finds all files within with an eager glob pattern.
    def discover_items_via_crawl(root)
      Dir.glob("#{root}/**/*").select { |fname| File.file?(fname) }
    end

    # ignores objects already pre-assembled as part of re-runnability of preassembly job
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
      un_pre_assembled_objects.each.with_index do |dobj, i|
        log "#{num_to_pre_assemble - i} remaining in run | #{num_to_pre_assemble} running"
        log "  - Processing object: #{dobj.container}"
        log "  - N object files: #{dobj.object_files.size}"
        @num_no_file_warnings += 1 if dobj.object_files.empty?
        load_checksums(dobj)
        progress = dobj.pre_assemble
        log "  - pre_assemble result: #{progress}"
        progress.merge!(pid: dobj.druid.id, container: dobj.container, timestamp: Time.now.utc.strftime('%Y-%m-%d %H:%M:%S'))
        @num_failures += 1 if progress[:status] == 'error'
        log "Completed #{dobj.druid}"
        File.open(progress_log_file, 'a') { |f| f.puts progress.to_yaml }
      end
    end
    # rubocop:enable Metrics/AbcSize

    def num_to_pre_assemble
      @num_to_pre_assemble ||= un_pre_assembled_objects.size
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
        staging_location: staging_location,
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
