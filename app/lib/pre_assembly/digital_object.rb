# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
module PreAssembly
  class DigitalObject
    include PreAssembly::Logging

    attr_reader :batch, :stageable_items, :object_files,
                :stager, :label, :druid, :source_id, :container

    delegate :staging_location,
             :processing_configuration,
             :content_structure,
             :ocr_available,
             :stt_available,
             :project_name,
             :file_manifest,
             to: :batch

    # @param [PreAssembly::Batch] batch
    # @param [PreAssembly::CopyStager, PreAssembly::LinkStager] stager the implementation of how to stage an object
    # @param [String] container the identifier (non-namespaced); i.e. the full path to the folder containing the object files
    # @param [Array<String>] stageable_items items to stage
    # @param [Array<ObjectFile>] object_files path to files that are part of the object
    # @param [String] label The label for this object
    # @param [String] pid The bare druid identifier for the item
    # @param [String] source_id The source identifier
    # rubocop:disable Metrics/ParameterLists
    def initialize(batch, stager:, container: '', stageable_items: nil, object_files: nil,
                   label: nil, pid: nil, source_id: nil)
      @batch = batch
      @container = container
      @stageable_items = stageable_items
      @object_files = object_files
      @label = label
      @druid = DruidTools::Druid.new(pid)
      @source_id = source_id
      @stager = stager
    end
    # rubocop:enable Metrics/ParameterLists

    # set this object's content_md_creation_style
    # @return [Symbol]
    def content_md_creation_style
      # map the object type to structural styles supported by the FileSetBuilder class
      {
        Cocina::Models::ObjectType.image => :simple_image,
        Cocina::Models::ObjectType.object => :file,
        Cocina::Models::ObjectType.book => :simple_book,
        Cocina::Models::ObjectType.manuscript => :simple_book,
        Cocina::Models::ObjectType.document => :document,
        Cocina::Models::ObjectType.map => :map,
        Cocina::Models::ObjectType.geo => :geo,
        Cocina::Models::ObjectType.three_dimensional => :'3d',
        Cocina::Models::ObjectType.webarchive_seed => :'webarchive-seed',
        Cocina::Models::ObjectType.agreement => :file
      }.fetch(object_type, content_structure.to_sym)
    end

    ####
    # The main process.
    ####

    # @return [Hash] the status of the attempt and an optional message
    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/MethodLength
    def pre_assemble
      log "  - pre_assemble(#{source_id}) started"
      if accessioning?
        return { pre_assem_finished: false,
                 status: 'error',
                 message: 'cannot accession when object is already in the process of accessioning' }
      end

      unless version_client.status.open?
        if openable?
          version_client.open(description: 'Accessioned via Preassembly')
        else
          return { pre_assem_finished: false,
                   status: 'error',
                   message: "can't be opened for a new version; cannot re-accession when version > 1 unless object can be opened" }
        end
      end

      if (object_validation_message = object_files_valid?)
        return { pre_assem_finished: false,
                 status: 'error',
                 message: object_validation_message }
      end

      @assembly_directory = AssemblyDirectory.create(druid_id: druid.id, base_path: container, content_structure:)
      stage_files
      update_structural_metadata
      StartAccession.run(druid: druid.druid, batch_context: batch.batch_context, workflow: default_workflow)
      log "    - pre_assemble(#{druid.id}) finished"
      # Return possibly incremented version.
      { pre_assem_finished: true, status: 'success', version: version_client.current.to_i }
    rescue StandardError => e
      log "    - pre_assemble(#{druid.id}) error occurred: #{e.message}"
      { pre_assem_finished: false, status: 'error', message: e.message }
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength

    def existing_cocina_object
      @existing_cocina_object ||= object_client.find
    end

    def default_workflow
      if content_structure == 'geo'
        'gisAssemblyWF'
      else
        'assemblyWF'
      end
    end

    def build_structural
      if file_manifest
        file_manifest.generate_structure(cocina_dro: existing_cocina_object, object: File.basename(container),
                                         reading_order:)
      else
        build_from_staging_location(objects: object_files.sort,
                                    processing_configuration:,
                                    ocr_available:,
                                    stt_available:,
                                    reading_order:)
      end
    end

    def current_object_version
      version_client.current.to_i
    end

    private

    attr_reader :assembly_directory

    # @return [String] one of the values from Cocina::Models::DRO::TYPES
    def object_type
      existing_cocina_object.type
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
        destination = assembly_directory.path_for(si_path)
        log "      - staging(#{si_path}, #{destination})", :debug
        stager.stage si_path, destination
      end
    end

    # Update dor-services-app with the new structure
    def update_structural_metadata
      updated_cocina = existing_cocina_object.new(structural: build_structural)
      object_client.update(params: updated_cocina)
    end

    def build_from_staging_location(objects:, processing_configuration:, reading_order:, ocr_available:, stt_available:)
      filesets = FromStagingLocation::FileSetBuilder.build(processing_configuration:, ocr_available:, stt_available:, objects:, style: content_md_creation_style)
      FromStagingLocation::StructuralBuilder.build(cocina_dro: existing_cocina_object,
                                                   filesets:,
                                                   all_files_public: batch.batch_context.all_files_public?,
                                                   reading_order:,
                                                   manually_corrected_ocr: batch.batch_context.manually_corrected_ocr,
                                                   manually_corrected_stt: batch.batch_context.manually_corrected_stt)
    end

    # The reading order for books is determined by what the user set when registering the object.
    # This is passed to the content metadata creator, which uses it if the content structure is book
    # Assume left-to-right if missing in the cocina structural (which really shouldn't happen for this content type)
    def reading_order
      return unless content_md_creation_style == :simple_book

      existing_cocina_object.structural&.hasMemberOrders&.first&.viewingDirection || 'left-to-right'
    end

    ####
    # Versioning for a re-accession.
    ####

    delegate :openable?, to: :version_client

    def object_client
      Dor::Services::Client.object(druid.druid)
    end

    def version_client
      object_client.version
    end

    def workflow_client
      Dor::Workflow::Client.new(url: Settings.workflow_url, timeout: Settings.workflow.timeout)
    end

    def accessioning?
      return true if workflow_client.active_lifecycle(
        druid: druid.druid,
        milestone_name: 'submitted',
        version: current_object_version.to_s
      )

      false
    end

    def object_files_valid?
      object_validator = ObjectFileValidator.new(object: self, batch:)
      if object_validator.object_has_hierarchy? && content_structure != 'file'
        "can't be accessioned -- if object files have hierarchy the content structure must be set to file"
      elsif object_validator.object_equals_druid?
        "can't be accessioned -- files and/or folder cannot be equal to the druid."
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
