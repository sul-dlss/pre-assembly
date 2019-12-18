# frozen_string_literal: true

module PreAssembly
  class Bundle
    include PreAssembly::Logging

    attr_reader :bundle_context
    attr_writer :digital_objects
    attr_accessor :user_params,
                  :skippables,
                  :media_manifest

    delegate :apo_druid_id,
             :apply_tag,
             :bundle_dir,
             :config_filename,
             :content_md_creation,
             :content_structure,
             :manifest_rows,
             :path_in_bundle,
             :progress_log_file,
             :project_name,
             :set_druid_id,
             :stageable_discovery,
             :staging_style_symlink,
             to: :bundle_context

    def initialize(bundle_context)
      @bundle_context = bundle_context
      self.media_manifest = PreAssembly::Media.new(csv_filename: bundle_context.media_manifest, bundle_dir: bundle_dir) if bundle_context.media_cm_style?
      self.skippables = {}
      load_skippables
    end

    def load_skippables
      return unless File.readable?(progress_log_file)
      docs = YAML.load_stream(IO.read(progress_log_file))
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

        DigitalObject.new(self,
                          container: c,
                          stageable_items: stageable_items,
                          object_files: discover_object_files(stageable_items),
                          label: row.fetch('label', ''),
                          source_id: row['sourceid'],
                          pid: row[:druid],
                          stager: stager)
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
      o2p = objects_to_process # Get the non-skipped objects to process
      total_obj = o2p.size
      log "process_digital_objects(#{total_obj} objects)"
      log "#{total_obj} objects to pre-assemble"
      log "#{digital_objects.size} total objects found, #{skippables.size} already completed objects skipped"

      o2p.each_with_index do |dobj, n|
        log "#{total_obj - n} remaining in run | #{total_obj} running"
        log "  - Processing object: #{dobj.container}"
        log "  - N object files: #{dobj.object_files.size}"
        num_no_file_warnings += 1 if dobj.object_files.empty?
        progress = { dobj: dobj }
        begin
          # Try to pre_assemble the digital object.
          load_checksums(dobj)
          dobj.pre_assemble
          # Indicate that we finished.
          progress[:pre_assem_finished] = true
          log "Completed #{dobj.druid}"
        ensure
          # Log the outcome no matter what.
          File.open(progress_log_file, 'a') { |f| f.puts log_progress_info(progress).to_yaml }
        end
      end
    ensure
      log "**WARNING**: #{num_no_file_warnings} objects had no files" if num_no_file_warnings > 0
      log "#{total_obj || 0} objects pre-assembled"
    end

    def objects_to_process
      @o2p ||= digital_objects.reject { |dobj| skippables.key?(dobj.container) }
    end

    def log_progress_info(info)
      {
        container: info[:dobj].container,
        pid: info[:dobj].pid,
        pre_assem_finished: info[:pre_assem_finished],
        timestamp: Time.now.strftime('%Y-%m-%d %H:%I:%S')
      }
    end

    private

    def stager
      staging_style_symlink ? LinkStager : CopyStager
    end

    # Discover object containers from a manifest.
    # The relative path to the container is supplied in one of the
    # manifest columns. The column name to use is configured by the
    # user invoking the pre-assembly script.
    def discover_containers_via_manifest
      manifest_rows.each_with_index { |r, i| raise "Missing 'object' in row #{i}: #{r}" unless r[:object] }
      manifest_rows.map { |r| path_in_bundle r[:object] }
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

    # Returns a list of the ObjectFiles for a digital object.
    def discover_object_files(stageable_items)
      object_files = []
      Array(stageable_items).each do |stageable|
        find_files_recursively(stageable).each do |file_path|
          object_files.push(new_object_file(stageable, file_path))
        end
      end
      object_files
    end

    # A convenience method to return all ObjectFiles for all digital objects.
    # Also used for stubbing during testing.
    def all_object_files
      digital_objects.map(&:object_files).flatten
    end

    # @return [PreAssembly::ObjectFile]
    def new_object_file(stageable, file_path)
      ObjectFile.new(
        file_path,
        relative_path: relative_path(get_base_dir(stageable), file_path)
      )
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
      raise ArgumentError, "Bad arg to get_base_dir(#{path.inspect})"
    end

    def dir_glob(pattern)
      Dir.glob(pattern).sort
    end

    # Takes a path to a file or dir. Returns all files (but not dirs) contained in the path, recursively.
    def find_files_recursively(path)
      patterns = [path, File.join(path, '**', '*')]
      Dir.glob(patterns).reject { |f| File.directory? f }.sort
    end
  end
end
