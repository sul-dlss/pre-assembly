# frozen_string_literal: true

module PreAssembly
  module FromStagingLocation
    # Represents a single File
    class File
      # default publish/preserve/shelve attributes used in content metadata
      # if no mimetype specific attributes are specified for a given file, define some defaults, and override for specific mimetypes below
      ATTRIBUTES_FOR_TYPE = {
        'default' => { preserve: 'yes', shelve: 'no', publish: 'no' },
        'image/tif' => { preserve: 'yes', shelve: 'no', publish: 'no' },
        'image/tiff' => { preserve: 'yes', shelve: 'no', publish: 'no' },
        'image/jp2' => { preserve: 'no', shelve: 'yes', publish: 'yes' },
        'image/jpeg' => { preserve: 'yes', shelve: 'no', publish: 'no' },
        'audio/wav' => { preserve: 'yes', shelve: 'no', publish: 'no' },
        'audio/x-wav' => { preserve: 'yes', shelve: 'no', publish: 'no' },
        'audio/mp3' => { preserve: 'no', shelve: 'yes', publish: 'yes' },
        'audio/mpeg' => { preserve: 'no', shelve: 'yes', publish: 'yes' },
        'application/pdf' => { preserve: 'yes', shelve: 'yes', publish: 'yes' },
        'plain/text' => { preserve: 'yes', shelve: 'yes', publish: 'yes' },
        'text/plain' => { preserve: 'yes', shelve: 'yes', publish: 'yes' },
        'image/png' => { preserve: 'yes', shelve: 'yes', publish: 'no' },
        'application/zip' => { preserve: 'yes', shelve: 'no', publish: 'no' },
        'application/json' => { preserve: 'yes', shelve: 'yes', publish: 'yes' }
      }.freeze

      # @param [Assembly::ObjectFile] file
      def initialize(file:)
        @file = file
      end

      delegate :sha1, :md5, :provider_md5, :mimetype, :filesize, to: :file

      def file_id(common_path:)
        # set file id attribute, first check the relative_path parameter on the object, and if it is set, just use that
        return file.relative_path if file.relative_path

        # if the relative_path attribute is not set, then use the path attribute and check to see if we need to remove the common part of the path
        common_path ? file.path.gsub(common_path, '') : file.path
      end

      def file_attributes
        file.file_attributes || ATTRIBUTES_FOR_TYPE[mimetype] || ATTRIBUTES_FOR_TYPE['default']
      end

      private

      attr_reader :file
    end
  end
end
