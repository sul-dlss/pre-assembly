# frozen_string_literal: true

# This class generates custom contentMetadata from a file manifest, used if the user opts for this when starting a job
# Documentation: https://github.com/sul-dlss/pre-assembly/wiki/Accessioning-complex-content

# It is used by pre-assembly during the accessioning process to produce custom content metadata if a file manifest is supplied

# Test with
# cm=PreAssembly::FileManifest.new(bundle_dir: File.join(Rails.root,'spec/test_data/media_audio_test'), csv_filename: 'file_manifest.csv', verbose: true)
# puts cm.generate_cm(druid: 'sn000dd0000', object: 'oo000oo0001', content_md_creation_style: :media)

# or in the context of a batch object:
# cm=PreAssembly::FileManifest.new(csv_filename: @content_md_creation[:file_manifest],bundle_dir: @bundle_dir, verbose: false)
# puts cm.generate_cm(druid: 'oo000oo0001', object: 'oo000oo0001', content_md_creation_style: :file)

module PreAssembly
  class FileManifest
    attr_reader :manifest, :rows, :csv_filename, :bundle_dir

    # the valid roles a file can have, if you specify a "role" column and the value is not one of these, it will be ignored
    VALID_ROLES = %w[transcription annotations derivative master].freeze

    def initialize(params)
      @bundle_dir = params[:bundle_dir]
      csv_file = params[:csv_filename] || 'file_manifest.csv'
      @csv_filename = File.join(@bundle_dir, csv_file)
      @manifest = {}
      # read CSV
      load_manifest # this will cache the entire manifest in @rows and @manifest
    end

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
        thumb = row[:thumb] && %w[true yes thumb].include?(row[:thumb].downcase) ? true : false

        # set the publish/preserve/shelve
        publish  = row[:publish]
        shelve   = row[:shelve]
        preserve = row[:preserve]

        manifest[object] ||= { files: [] }
        files_hash = { file_extention: file_extension, filename: row[:filename], label: row[:label], sequence: row[:sequence] }
        manifest[object][:files] << files_hash.merge(role: role, thumb: thumb, publish: publish, shelve: shelve, preserve: preserve, resource_type: resource_type)
      end
    end

    # actually generate content metadata for a specific object in the manifest
    # @return [String] XML
    def generate_cm(druid:, object:, content_md_creation_style:)
      return '' unless manifest[object]
      current_directory = Dir.pwd
      files = manifest[object][:files]
      current_seq = ''
      resources = {}

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

      # generate the base of the XML file for this new druid
      # generate content metadata
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.contentMetadata(objectId: druid, type: content_type(content_md_creation_style)) do
          resources.keys.sort.each do |seq|
            resource = resources[seq]
            resource_attributes = { sequence: seq.to_s, id: "#{druid}_#{seq}", type: resource[:resource_type] }
            resource_attributes[:thumb] = 'yes' if resource[:thumb] # add the thumb=yes attribute to the resource if it was marked that way in the manifest
            xml.resource(resource_attributes) do
              xml.label resource[:label]

              resource[:files].each do |file|
                filename = file[:filename] || ''
                publish  = file[:publish]  || 'true'
                preserve = file[:preserve] || 'true'
                shelve   = file[:shelve]   || 'true'

                # look for a checksum file named the same as this file
                checksum = nil
                FileUtils.cd(File.join(bundle_dir, object))
                md_files = Dir.glob('**/' + filename + '.md5')
                checksum = get_checksum(File.join(bundle_dir, object, md_files[0])) if md_files.size == 1 # we found a corresponding md5 file, read it
                file_hash = { id: filename, preserve: preserve, publish: publish, shelve: shelve }
                file_hash[:role] = file[:role] if file[:role]

                xml.file(file_hash) do
                  xml.checksum(checksum, type: 'md5') if checksum.present?
                end
              end
            end
          end
        end
      end
      FileUtils.cd(current_directory)
      builder.to_xml
    end

    def get_checksum(md5_file)
      s = IO.read(md5_file)
      checksums = s.scan(/[0-9a-fA-F]{32}/)
      checksums.first ? checksums.first.strip : ''
    end

    # this uses the assembly-objectfile gem to map the content_md_creation_style to the content type string in contentMetadata
    #  i.e. https://github.com/sul-dlss/pre-assembly/blob/main/app/lib/pre_assembly/digital_object.rb#L43
    #  to   https://github.com/sul-dlss/assembly-objectfile/blob/main/lib/assembly-objectfile/content_metadata.rb#L29
    # Note: "media" is not supported in the gem, but is available for custom generation with file manifests here
    def content_type(content_md_creation_style)
      return 'media' if content_md_creation_style == :media

      Assembly::ContentMetadata.object_level_type(content_md_creation_style)
    end
  end
end
