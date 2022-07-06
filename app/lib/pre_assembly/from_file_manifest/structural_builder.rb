# frozen_string_literal: true

module PreAssembly
  module FromFileManifest
    # Updates the Cocina::DROStructural metadata with the new structure derived from a file manifest
    class StructuralBuilder
      # rubocop:disable Metrics/ParameterLists
      # @param [String] reading_order
      def self.build(cocina_dro:, resources:, object:, staging_location:, content_md_creation_style:, reading_order: 'left-to-right')
        new(cocina_dro: cocina_dro, resources: resources, object: object, staging_location: staging_location,
            content_md_creation_style: content_md_creation_style, reading_order: reading_order).build
      end

      def initialize(cocina_dro:, resources:, object:, staging_location:, content_md_creation_style:, reading_order:)
        @cocina_dro = cocina_dro
        @resources = resources
        @object = object
        @staging_location = staging_location
        @content_md_creation_style = content_md_creation_style
        @reading_order = reading_order
      end
      # rubocop:enable Metrics/ParameterLists

      attr_reader :content_md_creation_style, :resources, :cocina_dro, :object, :staging_location, :common_path, :reading_order

      # generate the base of the Cocina Structural metadata for this new druid
      def build
        attributes = { contains: build_file_sets }
        attributes[:hasMemberOrders] = [{ viewingDirection: reading_order }] if content_md_creation_style == :simple_book

        cocina_dro.structural.new(attributes)
      end

      def build_file_sets
        resources.keys.sort.map do |seq|
          FromFileManifest::FileSetBuilder.build(resource: resources[seq],
                                                 external_identifier: "#{object}_#{seq}",
                                                 cocina_dro: cocina_dro,
                                                 object: object,
                                                 staging_location: staging_location)
        end
      end
    end
  end
end
