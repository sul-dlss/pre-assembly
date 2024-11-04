# frozen_string_literal: true

module PreAssembly
  # This class generates custom structural metadata from a file manifest (file_manifest.csv), used if the user opts for this when starting a job
  # Documentation: https://github.com/sul-dlss/pre-assembly/wiki/Accessioning-complex-content

  # It is used by pre-assembly during the accessioning process to produce custom content metadata if a file manifest is supplied
  class FileManifest
    attr_reader :csv_filename, :staging_location

    # the valid roles a file can have, if you specify a "role" column and the value is not one of these, it will be ignored
    VALID_ROLES = %w[
      annotations
      caption
      derivative
      master
      transcription
    ].freeze

    # the required columns that must exist in the file manifest
    REQUIRED_COLUMNS = %w[druid filename resource_label sequence publish shelve preserve resource_type role sdr_generated_text corrected_for_accessibility].freeze

    def initialize(staging_location:, csv_filename:)
      @staging_location = staging_location
      @csv_filename = csv_filename
    end

    # rubocop:disable Metrics/AbcSize
    def manifest
      @manifest ||= begin
        # load file into @rows and then build up @manifest; rejecting any blank rows
        rows = CsvImporter.parse_to_hash(@csv_filename).delete_if { |row| row['druid'].blank? }

        validate_rows(rows)

        sequence = nil
        rows.each_with_object({}) do |row, manifest|
          druid = row[:druid]
          sequence = row[:sequence].to_i if row[:sequence].present?
          manifest[druid] ||= { file_sets: {} }
          manifest[druid][:file_sets][sequence] ||= file_set_properties_from_row(row, sequence)
          manifest[druid][:file_sets][sequence][:files] << file_properties_from_row(row)
        end
      end
    end
    # rubocop:enable Metrics/AbcSize

    # actually generate content metadata for a specific object in the manifest
    # @returns [Cocina::Models::DROStructural] the structural metadata
    def generate_structure(cocina_dro:, object:, reading_order: nil)
      item_structure = manifest[object]
      raise "no structure found in manifest for `#{object}'" unless item_structure

      current_directory = Dir.pwd # this must be done before resources_hash is built
      structure = FromFileManifest::StructuralBuilder.build(cocina_dro:,
                                                            resources: item_structure,
                                                            reading_order:,
                                                            staging_location:)

      FileUtils.cd(current_directory)
      structure
    end

    private

    def validate_rows(rows)
      raise 'no rows in file_manifest or missing header' if rows.empty?

      missing_columns = REQUIRED_COLUMNS - rows.first.keys
      raise "file_manifest missing required columns: #{missing_columns.join(', ')}" unless missing_columns.empty?
    end

    def file_set_properties_from_row(row, sequence)
      {
        label: row[:resource_label].presence,
        sequence:,
        resource_type: row[:resource_type],
        files: []
      }.compact
    end

    # @param [HashWithIndifferentAccess] row
    # @return [Hash<Symbol,String>] The properties necessary to build a file.
    # rubocop:disable Metrics/AbcSize
    def file_properties_from_row(row)
      {
        type: Cocina::Models::ObjectType.file,
        externalIdentifier: FileIdentifierGenerator.generate,
        filename: row[:filename],
        label: row[:file_label].presence || row[:filename],
        languageTag: row[:file_language],
        use: VALID_ROLES.include?(row[:role]) ? row[:role] : nil, # filter out unexpected role values
        administrative: administrative(row),
        hasMessageDigests: md5_digest(row),
        hasMimeType: row[:mimetype].presence,
        access: access_properties_from_row(row),
        sdrGeneratedText: ActiveModel::Type::Boolean.new.cast(row[:sdr_generated_text]) || false,
        correctedForAccessibility: ActiveModel::Type::Boolean.new.cast(row[:corrected_for_accessibility]) || false
      }.compact
    end
    # rubocop:enable Metrics/AbcSize

    def access_properties_from_row(row)
      {
        view: row['rights_view'].presence,
        download: row['rights_download'].presence,
        location: row['rights_location'].presence
      }.compact.presence
    end

    def administrative(row)
      publish  = row[:publish] == 'yes'
      preserve = row[:preserve] == 'yes'
      shelve   = row[:shelve] == 'yes'

      raise 'file_manifest has preserve and shelve both being set to no for a single file' if !preserve && !shelve

      { sdrPreserve: preserve, publish:, shelve: }
    end

    def md5_digest(row)
      container_path = File.join(staging_location, row[:druid])
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
  end
end
