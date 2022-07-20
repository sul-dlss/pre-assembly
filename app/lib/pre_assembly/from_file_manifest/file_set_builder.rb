# frozen_string_literal: true

module PreAssembly
  module FromFileManifest
    # Creates a hash representing the Cocina::FileSets from a file manifest
    class FileSetBuilder
      # @param [Cocina::Models::DRO] cocina_dro
      def self.build(resource:, cocina_dro:, external_identifier:)
        new(
          resource: resource,
          cocina_dro: cocina_dro,
          external_identifier: external_identifier
        ).build
      end

      def initialize(resource:, cocina_dro:, external_identifier:)
        @resource = resource
        @cocina_dro = cocina_dro
        @external_identifier = external_identifier
      end

      attr_reader :resource, :cocina_dro, :external_identifier

      def build
        {
          label: resource[:label],
          type: resource_type(resource[:resource_type]),
          externalIdentifier: external_identifier,
          version: cocina_dro.version,
          structural: structural
        }
      end

      private

      def resource_type(val)
        val = 'three_dimensional' if val == '3d'
        return Cocina::Models::FileSetType.public_send(val) if val && Cocina::Models::FileSetType.respond_to?(val)

        raise "Invalid resource type: '#{val}'"
      end

      def structural
        { contains: build_files }
      end

      def build_files
        resource[:files].map { |file| file_builder(file: file) }
      end

      def file_builder(file:)
        filename = file.fetch(:filename)

        attributes = {
          externalIdentifier: "https://cocina.sul.stanford.edu/file/#{SecureRandom.uuid}",
          type: 'https://cocina.sul.stanford.edu/models/file',
          filename: filename,
          label: filename,
          version: cocina_dro.version,
          access: file_access,
          administrative: administrative(file)
        }
        attributes[:hasMessageDigests] = [{ type: 'md5', digest: file[:md5_digest] }] if file[:md5_digest]

        attributes[:use] = file[:role] if file[:role]

        Cocina::Models::File.new(attributes)
      end

      def administrative(file)
        publish  = file[:publish] == 'yes'
        preserve = file[:preserve] == 'yes'
        shelve   = file[:shelve] == 'yes'
        { sdrPreserve: preserve, publish: publish, shelve: shelve }
      end

      def file_access
        file_access = cocina_dro.access.to_h.slice(:view, :download, :location, :controlledDigitalLending)
        file_access[:view] = 'dark' if file_access[:view] == 'citation-only'
        file_access
      end
    end
  end
end
