# frozen_string_literal: true

module PreAssembly
  # This class generates custom structural metadata from a file manifest (file_manifest.csv), used if the user opts for this when starting a job
  # Documentation: https://github.com/sul-dlss/pre-assembly/wiki/Accessioning-complex-content

  # It is used by pre-assembly during the accessioning process to produce custom content metadata if a file manifest is supplied
  class FileManifest
    attr_reader :manifest, :csv_filename, :staging_location

    # the valid roles a file can have, if you specify a "role" column and the value is not one of these, it will be ignored
    VALID_ROLES = %w[transcription annotations derivative master].freeze

    def initialize(staging_location:, csv_filename:)
      @staging_location = staging_location
      @csv_filename = csv_filename
      # read CSV
      @manifest = load_manifest # this will cache the entire file manifest csv in @manifest
    end

    def valid?
      # check to see if any files in any file sets have both preserve and shelve set to "no" ... this makes no sense and should be marked as invalid
      files = manifest.map { |__object, resources| resources[:file_sets].map { |__num, file_set| file_set[:files] } }.flatten
      invalid_files = files.any? { |file| file.dig(:administrative, :sdrPreserve) == false && file.dig(:administrative, :shelve) == false }

      !invalid_files
    end

    # rubocop:disable Metrics/AbcSize
    def load_manifest
      # load file into @rows and then build up @manifest
      rows = CsvImporter.parse_to_hash(@csv_filename)
      sequence = nil
      rows.each_with_object({}) do |row, manifest|
        object = row[:object]
        sequence = row[:sequence].to_i if row[:sequence].present?
        manifest[object] ||= { file_sets: {} }
        manifest[object][:file_sets][sequence] ||= file_set_properties_from_row(row, sequence)
        manifest[object][:file_sets][sequence][:files] << file_properties_from_row(row)
      end
    end
    # rubocop:enable Metrics/AbcSize

    def file_set_properties_from_row(row, sequence)
      { label: row[:label], sequence:, resource_type: row[:resource_type], files: [] }
    end

    # @param [HashWithIndifferentAccess] row
    # @return [Hash<Symbol,String>] The properties necessary to build a file.
    def file_properties_from_row(row)
      {
        type: Cocina::Models::ObjectType.file,
        externalIdentifier: "https://cocina.sul.stanford.edu/file/#{SecureRandom.uuid}",
        filename: row[:filename],
        label: row[:filename],
        use: role(row),
        administrative: administrative(row),
        hasMessageDigests: md5_digest(row)
      }.compact
    end

    def administrative(row)
      publish  = row[:publish] == 'yes'
      preserve = row[:preserve] == 'yes'
      shelve   = row[:shelve] == 'yes'
      { sdrPreserve: preserve, publish:, shelve: }
    end

    # @return [String] the role for the file (if a valid role value, otherwise nil)
    def role(row)
      row[:role] if VALID_ROLES.include?(row[:role])
    end

    def md5_digest(row)
      container_path = File.join(staging_location, row[:object])
      # look for a checksum file named the same as this file
      md5_files = Dir.glob("#{container_path}/**/#{row[:filename]}.md5")
      # if we find a corresponding md5 file, read it
      return unless md5_files.size == 1

      digest = read_checksum_from_file(md5_files.first)
      return unless digest

      [{ type: 'md5', digest: }]
    end

    def read_checksum_from_file(md5_file)
      File.read(md5_file).scan(/[0-9a-fA-F]{32}/).first
    end

    # actually generate content metadata for a specific object in the manifest
    # @return [String] XML
    def generate_structure(cocina_dro:, object:, content_md_creation_style:, reading_order: 'left-to-right')
      item_structure = manifest[object]
      raise "no structure found in mainifest for `#{object}'" unless item_structure

      current_directory = Dir.pwd # this must be done before resources_hash is built
      structure = FromFileManifest::StructuralBuilder.build(cocina_dro:,
                                                            resources: item_structure,
                                                            content_md_creation_style:,
                                                            reading_order:)

      # write the contentMetadata.xml file
      FileUtils.cd(current_directory)
      structure
    end
  end
end
