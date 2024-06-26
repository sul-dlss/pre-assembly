# frozen_string_literal: true

module PreAssembly
  module FromStagingLocation
    # Creates a data structure of FileSets from a staging location
    class FileSetBuilder
      # @param [Symbol] processing_configuration one of: :default or :filename
      # @param [Array<Assembly::ObjectFile>] objects
      # @param [Symbol] style one of: :simple_image, :file, :simple_book, :book_as_image, :book_with_pdf, :map, :geo, or :'3d'
      def self.build(processing_configuration:, objects:, style:, ocr_available:)
        new(processing_configuration:, objects:, style:, ocr_available:).build
      end

      def initialize(processing_configuration:, objects:, style:, ocr_available:)
        @processing_configuration = processing_configuration.to_sym
        @objects = objects
        @style = style
        @ocr_available = ocr_available
      end

      # @return [Array<FileSet>] a list of filesets in the object
      def build
        return [] if style == :geo # geo does not need any files in structural metadata, will be created in geo specific workflows

        case processing_configuration
        when :default # one resource per object
          objects.collect { |obj| FileSet.new(resource_files: [obj], style:, ocr_available:) }
        when :filename, :filename_with_ocr # one resource per distinct filename (excluding extension)
          build_for_filename
        else
          raise 'Invalid processing_configuration: must be :default, :filename, or :filename_with_ocr'
        end
      end

      private

      attr_reader :processing_configuration, :objects, :style

      # until the new OCR settings are available, we have to look in the processing configuration
      def ocr_available
        if Settings.ocr.enabled
          @ocr_available
        else
          processing_configuration == :filename_with_ocr
        end
      end

      def build_for_filename
        # loop over distinct filenames, this determines how many resources we will have and
        # create one resource node per distinct filename, collecting the relevant objects with the distinct filename into that resource
        distinct_filenames = objects.collect(&:filename_without_ext).uniq # find all the unique filenames in the set of objects, leaving off extensions and base paths
        distinct_filenames.map do |distinct_filename|
          FileSet.new(resource_files: objects.collect { |obj| obj if obj.filename_without_ext == distinct_filename }.compact,
                      style:,
                      ocr_available:)
        end
      end
    end
  end
end
