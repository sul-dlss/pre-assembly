# frozen_string_literal: true

module PreAssembly
  module FromStagingLocation
    # Represents a groups of related Files, such as a single master file and the derivatives
    class FileSet
      VALID_THREE_DIMENSION_EXTENSIONS = ['.obj'].freeze

      # @param [Array<Assembly::ObjectFile>] resource_files
      # @param [Symbol] style one of: :simple_image, :file, :simple_book, :book_as_image, :book_with_pdf, :map, :geo, or :'3d'
      def initialize(resource_files:, style:, processing_configuration:)
        @resource_files = resource_files
        @style = style
        @processing_configuration = processing_configuration
      end

      # otherwise look at the style to determine the resource_type_description
      def resource_type_description
        @resource_type_description ||= resource_type_descriptions
      end

      def label_from_file(default:)
        resource_files.find { |res_file| res_file.label.present? }&.label || default
      end

      def files
        resource_files.map { |file| File.new(file:, processing_configuration:) }
      end

      private

      attr_reader :resource_files, :style, :processing_configuration

      # rubocop:disable Metrics/AbcSize
      # rubocop:disable Metrics/CyclomaticComplexity
      # rubocop:disable Metrics/MethodLength
      # rubocop:disable Metrics/PerceivedComplexity
      def resource_type_descriptions
        # grab all of the file types within a resource into an array so we can decide what the resource type should be
        resource_file_types = resource_files.collect(&:object_type)
        resource_has_non_images = !(resource_file_types - [:image]).empty?

        case style
        when :simple_image, :map, :'webarchive-seed'
          'image'
        when :file
          'file'
        when :simple_book # in a simple book project, all resources are pages unless they are *all* non-images -- if so, switch the type to object
          resource_has_non_images && resource_file_types.include?(:image) == false ? 'object' : 'page'
        when :book_as_image # same as simple book, but all resources are images instead of pages, unless we need to switch them to object type
          resource_has_non_images && resource_file_types.include?(:image) == false ? 'object' : 'image'
        when :book_with_pdf # in book with PDF type, if we find a resource with *any* non images, switch it's type from book to object
          resource_has_non_images ? 'object' : 'page'
        when :document
          'document'
        when :'3d'
          resource_extensions = resource_files.collect(&:ext)
          if resource_extensions.intersect?(VALID_THREE_DIMENSION_EXTENSIONS)
            '3d'
          else
            'file'
          end
        end
      end
      # rubocop:enable Metrics/PerceivedComplexity
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/AbcSize
    end
  end
end
