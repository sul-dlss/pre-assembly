# frozen_string_literal: true

module PreAssembly
  module FromFileManifest
    # Creates a hash representing the Cocina::FileSets from a file manifest
    class FileSetBuilder
      # @param [Cocina::Models::DRO] cocina_dro
      def self.build(resource:, cocina_dro:, external_identifier:, staging_location:)
        new(
          resource:,
          cocina_dro:,
          external_identifier:,
          staging_location:
        ).build
      end

      def initialize(resource:, cocina_dro:, external_identifier:, staging_location:)
        @resource = resource
        @cocina_dro = cocina_dro
        @external_identifier = external_identifier
        @staging_location = staging_location
      end

      attr_reader :resource, :cocina_dro, :external_identifier, :staging_location

      def build
        {
          label: resource[:label] || '',
          type: resource_type(resource[:resource_type]),
          externalIdentifier: external_identifier,
          version: cocina_dro.version,
          structural:
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
        resource[:files].map { |file_attributes| file_builder(file_attributes:) }
      end

      def file_builder(file_attributes:)
        attrs = file_attributes
                .merge(version: cocina_dro.version, access: file_access(file_attributes))
                .merge(existing_cocina_file_attributes(filename: file_attributes[:filename], mimetype_present: file_attributes[:hasMimeType].present?))
        Cocina::Models::File.new(attrs)
      end

      def existing_cocina_file_attributes(filename:, mimetype_present:)
        return {} if file_exists?(filename)
        return {} unless (existing_cocina_file = existing_cocina_files[filename])

        fields = :externalIdentifier, :hasMessageDigests, :size, :presentation
        fields << :hasMimeType unless mimetype_present

        existing_cocina_file.to_h.slice(*fields)
      end

      def file_exists?(filename)
        File.exist?(File.join(staging_location, cocina_dro.externalIdentifier.delete_prefix('druid:'), filename))
      end

      def file_access(file_attributes)
        return file_attributes[:access] if file_attributes[:access].present?

        file_access = cocina_dro.access.to_h.slice(:view, :download, :location, :controlledDigitalLending)
        file_access[:view] = 'dark' if file_access[:view] == 'citation-only'
        file_access
      end

      def existing_cocina_files
        @existing_cocina_files = cocina_dro.structural.contains.flat_map do |file_set|
          file_set.structural.contains.map { |file| [file.filename, file] }
        end.to_h
      end
    end
  end
end
