# frozen_string_literal: true

module PreAssembly
  module FromStagingLocation
    # Creates a data structure of FileSets from a staging location
    class FileSetBuilder
      # @param [Symbol] bundle one of: :default or :filename
      # @param [Array<Assembly::ObjectFile>] objects
      # @param [Symbol] style one of: :simple_image, :file, :simple_book, :book_as_image, :book_with_pdf, :map, or :'3d'
      def self.build(bundle:, objects:, style:)
        new(bundle: bundle, objects: objects, style: style).build
      end

      def initialize(bundle:, objects:, style:)
        @bundle = bundle
        @objects = objects
        @style = style
      end

      # @return [Array<FileSet>] a list of filesets in the object
      def build
        case bundle
        when :default # one resource per object
          objects.collect { |obj| FileSet.new(resource_files: [obj], style: style) }
        when :filename # one resource per distinct filename (excluding extension)
          build_for_filename
        else
          raise 'Invalid bundle method'
        end
      end

      private

      attr_reader :bundle, :objects, :style

      def build_for_filename
        # loop over distinct filenames, this determines how many resources we will have and
        # create one resource node per distinct filename, collecting the relevant objects with the distinct filename into that resource
        distinct_filenames = objects.collect(&:filename_without_ext).uniq # find all the unique filenames in the set of objects, leaving off extensions and base paths
        distinct_filenames.map do |distinct_filename|
          FileSet.new(resource_files: objects.collect { |obj| obj if obj.filename_without_ext == distinct_filename }.compact,
                      style: style)
        end
      end
    end
  end
end
