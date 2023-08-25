# frozen_string_literal: true

module PreAssembly
  module FromFileManifest
    # Updates the Cocina::DROStructural metadata with the new structure derived from a file manifest
    class StructuralBuilder
      # @param [String] reading_order
      def self.build(cocina_dro:, resources:, content_md_creation_style:, reading_order: 'left-to-right')
        new(cocina_dro:, resources:,
            content_md_creation_style:, reading_order:).build
      end

      def initialize(cocina_dro:, resources:, content_md_creation_style:, reading_order:)
        @cocina_dro = cocina_dro
        @resources = resources
        @content_md_creation_style = content_md_creation_style
        @reading_order = reading_order
      end
      attr_reader :content_md_creation_style, :resources, :cocina_dro, :reading_order

      # generate the base of the Cocina Structural metadata for this new druid
      # @return [Cocina::Models::DROStructural] the structural metadata
      def build
        attributes = { contains: build_file_sets }
        attributes[:hasMemberOrders] = [{ viewingDirection: reading_order }] if content_md_creation_style == :simple_book

        cocina_dro.structural.new(attributes)
      end

      def build_file_sets
        resources[:file_sets].keys.sort.map do |seq|
          external_identifier = "#{cocina_dro.externalIdentifier.delete_prefix('druid:')}_#{seq}"
          FromFileManifest::FileSetBuilder.build(resource: resources[:file_sets][seq],
                                                 external_identifier:,
                                                 cocina_dro:)
        end
      end
    end
  end
end
