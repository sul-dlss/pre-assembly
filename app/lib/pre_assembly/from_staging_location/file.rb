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

      ATTRIBUTES_FOR_TYPE_WITH_OCR = {
        'image/tif' => { preserve: 'yes', shelve: 'no', publish: 'no' },
        'image/tiff' => { preserve: 'yes', shelve: 'no', publish: 'no' },
        'image/jp2' => { preserve: 'yes', shelve: 'no', publish: 'no' },
        'image/jpeg' => { preserve: 'yes', shelve: 'no', publish: 'no' },
        'image/png' => { preserve: 'yes', shelve: 'no', publish: 'no' },
        'application/pdf' => { preserve: 'yes', shelve: 'yes', publish: 'yes' },
        'plain/text' => { preserve: 'yes', shelve: 'yes', publish: 'yes' },
        'text/plain' => { preserve: 'yes', shelve: 'yes', publish: 'yes' },
        'application/xml' => { preserve: 'yes', shelve: 'yes', publish: 'yes', role: 'transcription' }
      }.freeze

      # @param [Assembly::ObjectFile] file
      def initialize(file:, processing_configuration:)
        @file = file
        @processing_configuration = processing_configuration
      end

      delegate :sha1, :md5, :provider_md5, :mimetype, :filesize, :relative_path, to: :file

      def file_attributes
        file.file_attributes || file_attributes_for_mimetype(mimetype)
      end

      private

      attr_reader :file, :processing_configuration

      def file_attributes_for_mimetype(mimetype)
        return ATTRIBUTES_FOR_TYPE_WITH_OCR[mimetype] if processing_configuration == :filename_with_ocr && ATTRIBUTES_FOR_TYPE_WITH_OCR.key?(mimetype)

        ATTRIBUTES_FOR_TYPE[mimetype] || ATTRIBUTES_FOR_TYPE['default']
      end
    end
  end
end
