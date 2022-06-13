# frozen_string_literal: true

# This class generates custom contentMetadata from a file manifest (file_manifest.csv), used if the user opts for this when starting a job
# Documentation: https://github.com/sul-dlss/pre-assembly/wiki/Accessioning-complex-content

# It is used by pre-assembly during the accessioning process to produce custom content metadata if a file manifest is supplied

# Test with
# cm=PreAssembly::FileManifest.new(staging_location: File.join(Rails.root,'spec/test_data/media_audio_test'), csv_filename: 'file_manifest.csv', verbose: true)
# puts cm.generate_cm(druid: 'sn000dd0000', object: 'oo000oo0001', content_md_creation_style: :media)

# or in the context of a batch object:
# cm=PreAssembly::FileManifest.new(csv_filename: @content_md_creation[:file_manifest],staging_location: @staging_location, verbose: false)
# puts cm.generate_cm(druid: 'oo000oo0001', object: 'oo000oo0001', content_md_creation_style: :file)

module PreAssembly
  class FileManifest
    attr_reader :manifest, :rows, :csv_filename, :staging_location

    # the valid roles a file can have, if you specify a "role" column and the value is not one of these, it will be ignored
    VALID_ROLES = %w[transcription annotations derivative master].freeze

    def initialize(params)
      @staging_location = params[:staging_location]
      csv_file = params[:csv_filename] || BatchContext.new.file_manifest
      @csv_filename = File.join(@staging_location, csv_file)
      @manifest = {}
      # read CSV
      load_manifest # this will cache the entire file manifest csv in @rows and @manifest
    end

    # rubocop:disable Metrics/AbcSize
    def load_manifest
      # load file into @rows and then build up @manifest
      @rows = CsvImporter.parse_to_hash(@csv_filename)
      @rows.each do |row|
        object = row[:object]
        file_extension = File.extname(row[:filename])
        resource_type = row[:resource_type]

        # set the role for the file (if a valid role value, otherwise it will be left off)
        role = row[:role] if VALID_ROLES.include?(row[:role])

        # set the thumb attribute for this resource - if it is set in the manifest to true, yes or thumb (set to false if no value or column is missing)
        thumb = row[:thumb] && %w[true yes thumb].include?(row[:thumb].downcase)

        # set the publish/preserve/shelve
        publish  = row[:publish]
        shelve   = row[:shelve]
        preserve = row[:preserve]

        manifest[object] ||= { files: [] }
        files_hash = { file_extention: file_extension, filename: row[:filename], label: row[:label], sequence: row[:sequence] }
        manifest[object][:files] << files_hash.merge(role: role, thumb: thumb, publish: publish, shelve: shelve, preserve: preserve, resource_type: resource_type)
      end
    end
    # rubocop:enable Metrics/AbcSize

    # actually generate content metadata for a specific object in the manifest
    # @return [String] XML
    def generate_structure(cocina_dro:, object:, content_md_creation_style:, reading_order: 'left-to-right')
      raise "no structure found in mainifest for `#{object}'" unless manifest[object]

      current_directory = Dir.pwd # this must be done before resources_hash is built
      resources = resources_hash(object: object)
      structure = FromFileManifest::StructuralBuilder.build(cocina_dro: cocina_dro,
                                                            resources: resources,
                                                            object: object, staging_location: staging_location,
                                                            content_md_creation_style: content_md_creation_style,
                                                            reading_order: reading_order)

      # write the contentMetadata.xml file
      FileUtils.cd(current_directory)
      structure
    end

    # return hash containing resource info to be used in generating content_metadata
    # rubocop:disable Metrics/AbcSize
    def resources_hash(object:)
      resources = {}

      files = manifest[object][:files]
      current_seq = ''

      # group the files into resources based on the sequence number defined in the manifest
      #  a new sequence number triggers a new resource
      files.each do |file|
        seq = file[:sequence]
        label = file[:label] || ''
        resource_type = file[:resource_type]
        if seq.present? && seq != current_seq # this is a new resource if we have a non-blank different sequence number
          resources[seq.to_i] = { label: label, sequence: seq, resource_type: resource_type, files: [] }
          current_seq = seq
        end
        resources[current_seq.to_i][:files] << file
        resources[current_seq.to_i][:thumb] = file[:thumb] if file[:thumb] # any true/yes thumb attribute for any file in that resource triggers the whole resource as thumb=true
      end

      resources
    end
    # rubocop:enable Metrics/AbcSize
  end
end
