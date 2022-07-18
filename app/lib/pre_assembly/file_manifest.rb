# frozen_string_literal: true

module PreAssembly
  # This class generates custom structural metadata from a file manifest (file_manifest.csv), used if the user opts for this when starting a job
  # Documentation: https://github.com/sul-dlss/pre-assembly/wiki/Accessioning-complex-content

  # It is used by pre-assembly during the accessioning process to produce custom content metadata if a file manifest is supplied
  class FileManifest
    attr_reader :manifest, :csv, :staging_location

    # the valid roles a file can have, if you specify a "role" column and the value is not one of these, it will be ignored
    VALID_ROLES = %w[transcription annotations derivative master].freeze

    def initialize(staging_location:, csv:)
      @staging_location = staging_location
      @csv = csv
      @manifest = load_manifest # this will cache the entire file manifest csv in @manifest
    end

    # rubocop:disable Metrics/AbcSize
    def load_manifest
      sequence = nil
      @csv.each_with_object({}) do |row, manifest|
        folder_name = folder(row)
        sequence = row['sequence'].to_i if row['sequence'].present?
        manifest[folder_name] ||= { file_sets: {} }
        manifest[folder_name][:file_sets][sequence] ||= file_set_properties_from_row(row, sequence)
        manifest[folder_name][:file_sets][sequence][:files] << file_properties_from_row(row, folder_name)
      end
    end
    # rubocop:enable Metrics/AbcSize

    def file_set_properties_from_row(row, sequence)
      { label: file_set_label(row), sequence: sequence, resource_type: row['resource_type'], files: [] }
    end

    # @param [HashWithIndifferentAccess] row
    # @return [Hash<Symbol,String>] The properties necessary to build a file.
    def file_properties_from_row(row, folder_name)
      {
        type: Cocina::Models::ObjectType.file,
        externalIdentifier: "https://cocina.sul.stanford.edu/file/#{SecureRandom.uuid}",
        filename: row['filename'],
        label: row['filename'],
        use: role(row),
        administrative: administrative(row),
        hasMessageDigests: md5_digest(row, folder_name)
      }.compact
    end

    def administrative(row)
      publish  = row['publish'] == 'yes'
      preserve = row['preserve'] == 'yes'
      shelve   = row['shelve'] == 'yes'
      { sdrPreserve: preserve, publish: publish, shelve: shelve }
    end

    # What is the folder name for this row
    def folder(row)
      row['object']
    end

    def file_set_label(row)
      row['label']
    end

    def file_label(row)
      row['filename']
    end

    # @return [String] the role for the file (if a valid role value, otherwise nil)
    def role(row)
      row['role'] if VALID_ROLES.include?(row['role'])
    end

    def md5_digest(row, folder_name)
      container_path = File.join(staging_location, folder_name)
      # look for a checksum file named the same as this file
      md5_files = Dir.glob("#{container_path}/**/#{row['filename']}.md5")
      # if we find a corresponding md5 file, read it
      return unless md5_files.size == 1

      digest = read_checksum_from_file(md5_files.first)
      return unless digest

      [{ type: 'md5', digest: digest }]
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
