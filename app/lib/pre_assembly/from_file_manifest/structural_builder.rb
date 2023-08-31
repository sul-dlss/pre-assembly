# frozen_string_literal: true

module PreAssembly
  module FromFileManifest
    # Updates the Cocina::DROStructural metadata with the new structure derived from a file manifest
    class StructuralBuilder
      # @param [String,nil] reading_order
      def self.build(cocina_dro:, resources:, reading_order: nil)
        new(cocina_dro:, resources:, reading_order:).build
      end

      def initialize(cocina_dro:, resources:, reading_order: nil)
        @cocina_dro = cocina_dro
        @resources = resources
        @reading_order = reading_order
      end
      attr_reader :resources, :cocina_dro, :reading_order

      # generate the base of the Cocina Structural metadata for this new druid
      # @return [Cocina::Models::DROStructural] the structural metadata
      def build
        attributes = { contains: build_file_sets }
        attributes[:hasMemberOrders] = [{ viewingDirection: reading_order }] if reading_order

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
