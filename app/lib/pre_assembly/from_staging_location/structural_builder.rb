# frozen_string_literal: true

module PreAssembly
  module FromStagingLocation
    # Updates the Cocina::DROStructural metadata with the new structure derived from a staging location
    class StructuralBuilder
      # rubocop:disable Metrics/ParameterLists
      # @param [Array<Fileset>] filesets
      # @param [Cocina::Models::DRO] cocina_dro
      # @param [String] common_path
      # @param [String] reading_order
      # @param [Boolean] all_files_public
      def self.build(filesets:, cocina_dro:, common_path:, content_md_creation_style:, reading_order:, all_files_public:)
        new(filesets: filesets, cocina_dro: cocina_dro, common_path: common_path,
            content_md_creation_style: content_md_creation_style, reading_order: reading_order,
            all_files_public: all_files_public).build
      end

      def initialize(filesets:, cocina_dro:, common_path:, content_md_creation_style:, reading_order:, all_files_public:)
        @filesets = filesets
        @cocina_dro = cocina_dro
        @common_path = common_path
        @content_md_creation_style = content_md_creation_style
        @reading_order = reading_order
        @all_files_public = all_files_public
      end
      # rubocop:enable Metrics/ParameterLists

      attr_reader :content_md_creation_style, :filesets, :cocina_dro, :common_path, :reading_order, :all_files_public

      # rubocop:disable Metrics/AbcSize
      # rubocop:disable Metrics/MethodLength
      def build
        # a counter to use when creating auto-labels for resources, with incremenets for each type
        resource_type_counters = Hash.new(0)

        # rubocop:disable Metrics/BlockLength
        cocina_filesets = filesets.map.with_index(1) do |fileset, sequence|
          resource_type_counters[fileset.resource_type_description] += 1 # each resource type description gets its own incrementing counter
          # create a generic resource label if needed
          default_label = "#{fileset.resource_type_description.capitalize} #{resource_type_counters[fileset.resource_type_description]}"
          # but if one of the files has a label, use it instead
          resource_label = fileset.label_from_file(default: default_label)
          contained_files = fileset.files.map do |obj| # iterate over all the files in a resource
            file_id = obj.file_id(common_path: common_path)
            file_attributes = {
              type: 'https://cocina.sul.stanford.edu/models/file',
              externalIdentifier: "https://cocina.sul.stanford.edu/file/#{SecureRandom.uuid}",
              version: version,
              label: file_id,
              filename: file_id,
              hasMessageDigests: message_digests(obj),
              hasMimeType: obj.mimetype,
              administrative: administrative(obj),
              access: file_access
            }
            Cocina::Models::File.new(file_attributes)
          end

          fs_attributes = {
            label: resource_label,
            version: version,
            externalIdentifier: "#{external_identifier.delete_prefix('druid:')}_#{sequence}",
            type: file_set_type(fileset.resource_type_description),
            structural: { contains: contained_files }
          }

          Cocina::Models::FileSet.new(fs_attributes)
        end
        # rubocop:enable Metrics/BlockLength

        attributes = { contains: cocina_filesets }
        attributes[:hasMemberOrders] = [{ viewingDirection: reading_order }] if content_md_creation_style == :simple_book

        cocina_dro.structural.new(attributes)
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength

      private

      delegate :version, to: :cocina_dro

      def external_identifier
        cocina_dro.externalIdentifier
      end

      def dro_access
        cocina_dro.access
      end

      def file_access
        file_access = dro_access.to_h.slice(:view, :download, :location, :controlledDigitalLending)
        file_access[:view] = 'dark' if file_access[:view] == 'citation-only'
        file_access
      end

      def file_set_type(val)
        val = 'three_dimensional' if val == '3d'
        return Cocina::Models::FileSetType.public_send(val) if val && Cocina::Models::FileSetType.respond_to?(val)

        raise "Invalid resource type: '#{val}'"
      end

      def administrative(obj)
        return { sdrPreserve: true, publish: true, shelve: true } if all_files_public
        return { sdrPreserve: true, shelve: false, publish: false } if dro_access.view == 'dark'

        file = obj.file_attributes
        publish  = file[:publish] == 'yes'
        preserve = file[:preserve] == 'yes'
        shelve   = file[:shelve] == 'yes'
        { sdrPreserve: preserve, publish: publish, shelve: shelve }
      end

      def message_digests(obj)
        obj.provider_md5 ? [{ type: 'md5', digest: obj.provider_md5 }] : []
      end
    end
  end
end
