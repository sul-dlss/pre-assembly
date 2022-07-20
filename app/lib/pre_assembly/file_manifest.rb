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

    def exists?
      File.exist?(csv_filename)
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
      { label: row[:label], sequence: sequence, resource_type: row[:resource_type], files: [] }
    end

    # @param [HashWithIndifferentAccess] row
    # @return [Hash<Symbol,String>] The properties necessary to build a file.
    def file_properties_from_row(row)
      {
        filename: row[:filename],
        label: row[:label],
        sequence: row[:sequence],
        role: role(row),
        publish: row[:publish],
        shelve: row[:shelve],
        preserve: row[:preserve],
        resource_type: row[:resource_type],
        md5_digest: md5_digest(row)
      }
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
      read_checksum_from_file(md5_files.first) if md5_files.size == 1
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
      structure = FromFileManifest::StructuralBuilder.build(cocina_dro: cocina_dro,
                                                            resources: item_structure,
                                                            content_md_creation_style: content_md_creation_style,
                                                            reading_order: reading_order)

      # write the contentMetadata.xml file
      FileUtils.cd(current_directory)
      structure
    end
  end
end
