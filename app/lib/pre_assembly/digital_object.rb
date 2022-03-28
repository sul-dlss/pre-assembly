# frozen_string_literal: true

module PreAssembly
  class DigitalObject
    include PreAssembly::Logging

    attr_reader :batch, :stageable_items, :object_files,
                :stager, :label, :pid, :source_id, :container

    delegate :bundle_dir,
             :content_md_creation,
             :content_structure,
             :project_name,
             :file_manifest,
             :using_file_manifest,
             to: :batch

    # @param [PreAssembly::Batch] batch
    # @param [String] container the identifier (non-namespaced); i.e. the full path to the folder containing the object files
    # @param [Array<String>] stageable_items items to stage
    # @param [Array<ObjectFile>] object_files path to files that are part of the object
    # @param [String] label The label for this object
    # @param [String] pid The identifier for the item
    # @param [String] source_id The source identifier
    # @param [Object] stager the implementation of how to stage an object
    # @param [Bool] dark does this object have "dark" access
    # rubocop:disable Metrics/ParameterLists
    def initialize(batch, container: '', stageable_items: nil, object_files: nil,
                   label: nil, pid: nil, source_id: nil, stager:, dark:)
      @batch = batch
      @container = container
      @stageable_items = stageable_items
      @object_files = object_files
      @label = label
      @pid = pid
      @source_id = source_id
      @stager = stager
      @dark = dark
    end
    # rubocop:enable Metrics/ParameterLists

    # set this object's content_md_creation_style
    # @return [Symbol]
    def content_md_creation_style
      # map the object type to content metadata creation styles supported by the assembly-objectfile gem

      # special case: content_structure of 'simple_book_rtl' always maps to simple_book
      #  with the reading order set separately when creating content metadata
      return :simple_book if content_structure == 'simple_book_rtl'

      {
        Cocina::Models::ObjectType.image => :simple_image,
        Cocina::Models::ObjectType.object => :file,
        Cocina::Models::ObjectType.book => :simple_book,
        Cocina::Models::ObjectType.manuscript => :simple_book,
        Cocina::Models::ObjectType.document => :document,
        Cocina::Models::ObjectType.map => :map,
        Cocina::Models::ObjectType.three_dimensional => :'3d',
        Cocina::Models::ObjectType.webarchive_seed => :'webarchive-seed',
        Cocina::Models::ObjectType.agreement => :file
      }.fetch(object_type, content_structure.to_sym)
    end

    ####
    # The main process.
    ####

    # @param [Boolean] file_attributes_supplied - set to true if publish/preserve/shelve attribs are supplied
    # @return [Hash] the status of the attempt and an optional message
    # rubocop:disable Metrics/AbcSize
    def pre_assemble(file_attributes_supplied = false)
      log "  - pre_assemble(#{source_id}) started"
      return { status: 'error', message: "can't be opened for a new version; cannot re-accession when version > 1 unless object can be opened" } if !openable? && current_object_version > 1

      @assembly_directory = AssemblyDirectory.create(druid_id: druid.id)
      stage_files
      generate_content_metadata(file_attributes_supplied)
      StartAccession.run(druid: druid.druid, user: batch.batch_context.user.sunet_id)
      log "    - pre_assemble(#{pid}) finished"
      { status: 'success' }
    end
    # rubocop:enable Metrics/AbcSize

    ####
    # Determining the druid.
    ####

    # @return [DruidTools::Druid]
    def druid
      @druid ||= DruidTools::Druid.new(pid)
    end

    def dark?
      @dark
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

    # Write contentMetadata.xml file
    # @param [Boolean] file_attributes_supplied - true if publish/preserve/shelve attribs are supplied
    def generate_content_metadata(file_attributes_supplied)
      File.open(assembly_directory.content_metadata_file, 'w') { |fh| fh.puts create_content_metadata(file_attributes_supplied) }
    end

    # The reading order for books is determined by the content structure set, defaulting to 'ltr'
    # This is passed to the content metadata creator, which uses it if the content structure is book
    def reading_order
      if content_structure == 'simple_book_rtl'
        'rtl'
      else
        'ltr'
      end
    end

    # Invoke the contentMetadata creation method used by the project
    # @param [Boolean] file_attributes_supplied - true if publish/preserve/shelve attribs are supplied
    def create_content_metadata(file_attributes_supplied)
      ContentMetadataCreator.new(druid_id: druid.id,
                                 object: File.basename(container),
                                 content_md_creation: content_md_creation,
                                 object_files: object_files,
                                 content_md_creation_style: content_md_creation_style,
                                 file_manifest: file_manifest,
                                 reading_order: reading_order,
                                 using_file_manifest: using_file_manifest,
                                 add_file_attributes: file_attributes_supplied).create
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
  end
end
