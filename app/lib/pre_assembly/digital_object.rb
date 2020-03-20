# frozen_string_literal: true

module PreAssembly
  class DigitalObject
    include PreAssembly::Logging

    attr_reader :bundle, :stageable_items, :object_files,
                :stager, :label, :pid, :source_id, :container

    delegate :bundle_dir,
             :content_md_creation,
             :content_structure,
             :project_name,
             :media_manifest,
             to: :bundle

    # @param [PreAssembly::Bundle] bundle
    # @param [String] container the identifier (non-namespaced)
    # @param [Array<String>] stageable_items items to stage
    # @param [Array<ObjectFile>] object_files path to files that are part of the object
    # @param [String] label The label for this object
    # @param [String] pid The identifier for the item
    # @param [String] source_id The source identifier
    # @param [Object] stager the implementation of how to stage an object
    # rubocop:disable Metrics/ParameterLists
    def initialize(bundle, container: nil, stageable_items: nil, object_files: nil,
                   label: nil, pid: nil, source_id: nil, stager:)
      @bundle = bundle
      @container = container
      @stageable_items = stageable_items
      @object_files = object_files
      @label = label
      @pid = pid
      @source_id = source_id
      @stager = stager
    end
    # rubocop:enable Metrics/ParameterLists

    # set this object's content_md_creation_style
    # @return [Symbol]
    def content_md_creation_style
      # map the object type to content metadata creation styles supported by the assembly-objectfile gem
      {
        Cocina::Models::Vocab.image => :simple_image,
        Cocina::Models::Vocab.object => :file,
        Cocina::Models::Vocab.book => :simple_book,
        Cocina::Models::Vocab.manuscript => :simple_book,
        Cocina::Models::Vocab.map => :map,
        Cocina::Models::Vocab.three_dimensional => :'3d'
      }.fetch(object_type, content_structure.to_sym)
    end

    ####
    # The main process.
    ####

    # @return [Hash] the status of the attempt and an optional message
    def pre_assemble
      log "  - pre_assemble(#{source_id}) started"
      return { status: 'error', message: "can't be opened for a new version; cannot re-accession when version > 1 unless object can be opened" } if !openable? && current_object_version > 1
      @assembly_directory = AssemblyDirectory.create(druid_id: druid.id)
      stage_files
      generate_content_metadata
      generate_media_project_technical_metadata if content_md_creation == 'media_cm_style'
      create_new_version if openable?
      initialize_assembly_workflow
      log "    - pre_assemble(#{pid}) finished"
      { status: 'success' }
    end

    ####
    # Determining the druid.
    ####

    # @return [DruidTools::Druid]
    def druid
      @druid ||= DruidTools::Druid.new(pid)
    end

    private

    attr_reader :assembly_directory

    # @return [String] one of the values from Cocina::Models::DRO::TYPES
    def object_type
      object_client.find.type
    rescue Dor::Services::Client::NotFoundResponse
      ''
    end

    ####
    # Staging files.
    ####

    # Create the druid tree within the staging directory,
    # and then copy-recursive all stageable items to that area.
    def stage_files
      log "    - staging(druid_tree_dir = #{assembly_directory.druid_tree_dir.inspect})"
      stageable_items.each do |si_path|
        # determine destination of staged file by looking to see if it is a known datastream XML file or not
        destination = assembly_directory.path_for(si_path)
        log "      - staging(#{si_path}, #{destination})", :debug
        stager.stage si_path, destination
      end
    end

    # generate technical metadata for media projects
    def generate_media_project_technical_metadata
      technical_md_xml = MediaProjectTechnicalMetadataCreator.new(pid: pid,
                                                                  bundle_dir: bundle_dir,
                                                                  container: container).create
      return if technical_md_xml.blank?
      file_name = assembly_directory.technical_metadata_file
      log "    - write_technical_metadata_xml(#{file_name})"
      File.open(file_name, 'w') { |fh| fh.puts technical_md_xml }
    end

    # Write contentMetadata.xml file
    def generate_content_metadata
      File.open(assembly_directory.content_metadata_file, 'w') { |fh| fh.puts create_content_metadata }
    end

    # Invoke the contentMetadata creation method used by the project
    def create_content_metadata
      ContentMetadataCreator.new(druid_id: druid.id,
                                 content_md_creation: content_md_creation,
                                 object_files: object_files,
                                 content_md_creation_style: content_md_creation_style,
                                 media_manifest: media_manifest,
                                 add_file_attributes: bundle.bundle_context.all_files_public?).create
    end

    ####
    # Versioning for a re-accession.
    ####

    def openable?
      version_client.openable?
    end

    def object_client
      @object_client ||= Dor::Services::Client.object(druid.druid)
    end

    def version_client
      object_client.version
    end

    def current_object_version
      @current_object_version ||= version_client.current.to_i
    end

    # When reaccessioning, we need to first open and close a version without kicking off accessionWF
    def create_new_version
      version_client.open(
        significance: 'major',
        description: 'pre-assembly re-accession',
        opening_user_name: bundle.bundle_context.user.sunet_id
      )
      version_client.close(start_accession: false)
    end

    ####
    # Initialize the assembly workflow.
    ####

    # Call web service to add assemblyWF to the object in DOR.
    def initialize_assembly_workflow
      workflow_client.create_workflow_by_name(druid.druid, 'assemblyWF', version: current_object_version)
    end

    def workflow_client
      logger = Logger.new(Settings.workflow.logfile, Settings.workflow.shift_age)
      Dor::Workflow::Client.new(url: Settings.workflow_url, logger: logger, timeout: Settings.workflow.timeout)
    end
  end
end
