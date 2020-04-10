# frozen_string_literal: true

# This class generates contentMetadata from a Media supplied manifest
# see the "SMPL Content" section here for a description of the manifest:
# https://consul.stanford.edu/pages/viewpage.action?pageId=136365158#AutomatedAccessioningandObjectRemediation(pre-assemblyandassembly)-SMPLContent

# It is used by pre-assembly during the accessioning process in an automated way based on the pre-assembly config .yml file setting of content_md_creation

# Test with
# cm=PreAssembly::Media.new(bundle_dir: '/thumpers/dpgthumper2-media/ARS0022_speech/content_ready_for_accessioning/content', csv_filename: 'media_manifest.csv', verbose: true)
# cm.generate_cm('zx248jc1918')

# or in the context of a batch object:
# cm=PreAssembly::Media.new(csv_filename: @content_md_creation[:media_manifest],bundle_dir: @bundle_dir, verbose: false)
# cm.generate_cm('oo000oo0001')

module PreAssembly
  class Media
    attr_reader :file_attributes, :manifest, :rows, :csv_filename, :bundle_dir

    def initialize(params)
      @bundle_dir = params[:bundle_dir]
      csv_file = params[:csv_filename] || 'media_manifest.csv'
      @csv_filename = File.join(@bundle_dir, csv_file)

      # default publish/shelve/preserve attributes per "type" as defined in media filenames
      @file_attributes = {
        'default' => { publish: 'no', shelve: 'no', preserve: 'yes' },
        'pm' => { publish: 'no', shelve: 'no', preserve: 'yes' },
        'sh' => { publish: 'no', shelve: 'no', preserve: 'yes' },
        'sl' => { publish: 'yes', shelve: 'yes', preserve: 'yes' },
        'images' => { publish: 'yes', shelve: 'yes', preserve: 'yes' },
        'transcript' => { publish: 'yes', shelve: 'yes', preserve: 'yes' }
      }
      @manifest = {}
      # read CSV
      load_manifest # this will cache the entire manifest in @rows and @manifest
    end

    def load_manifest
      # load file into @rows and then build up @manifest
      @rows = CsvImporter.parse_to_hash(@csv_filename)
      @rows.each do |row|
        druid = get_druid(row[:filename])
        role = get_role(row[:filename])
        file_extension = File.extname(row[:filename])
        # set the resource type if available, otherwise we'll use a default
        resource_type = row[:resource_type] || nil

        # set the thumb attribute for this resource if it is set in the manifest to true, yes or thumb (set to false if no value or column is missing)
        thumb = row[:thumb] && %w[true yes thumb].include?(row[:thumb].downcase) ? true : false

        # set the publish/preserve/shelve if available, otherwise we'll use the defaults
        publish  = row[:publish]  || nil
        shelve   = row[:shelve]   || nil
        preserve = row[:preserve] || nil

        manifest[druid] ||= { source_id: '', files: [] }
        manifest[druid][:source_id] = row[:source_id] if row[:source_id]
        files_hash = { role: role, file_extention: file_extension, filename: row[:filename], label: row[:label], sequence: row[:sequence] }
        manifest[druid][:files] << files_hash.merge(thumb: thumb, publish: publish, shelve: shelve, preserve: preserve, resource_type: resource_type)
      end
    end

    # actually generate content metadata for a specific druid in the manifest
    # @return [String] XML
    def generate_cm(druid)
      return '' unless manifest[druid]
      current_directory = Dir.pwd
      files = manifest[druid][:files]
      current_seq = ''
      resources = {}

      # group the files into resources based on the sequence number defined in the manifest
      #  a new sequence number triggers a new resource
      files.each do |file|
        seq = file[:sequence]
        label = file[:label] || ''
        resource_type = file[:resource_type] || 'media'
        if !seq.nil? && seq != '' && seq != current_seq # this is a new resource if we have a non-blank different sequence number
          resources[seq.to_i] = { label: label, sequence: seq, resource_type: resource_type, files: [] }
          current_seq = seq
        end
        resources[current_seq.to_i][:files] << file
        resources[current_seq.to_i][:thumb] = file[:thumb] if file[:thumb] # any true/yes thumb attribute for any file in that resource triggers the whole resource as thumb=true
      end

      # generate the base of the XML file for this new druid
      # generate content metadata
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.contentMetadata(objectId: druid, type: 'media') do
          resources.keys.sort.each do |seq|
            resource = resources[seq]
            resource_attributes = { sequence: seq.to_s, id: "#{druid}_#{seq}", type: resource[:resource_type] }
            resource_attributes[:thumb] = 'yes' if resource[:thumb] # add the thumb=yes attribute to the resource if it was marked that way in the manifest
            xml.resource(resource_attributes) do
              xml.label resource[:label]

              resource[:files].each do |file|
                filename = file[:filename] || ''
                attrs    = file_attributes[file[:role].downcase] || file_attributes['default']
                publish  = file[:publish]  || attrs[:publish]  || 'true'
                preserve = file[:preserve] || attrs[:preserve] || 'true'
                shelve   = file[:shelve]   || attrs[:shelve]   || 'true'

                # look for a checksum file named the same as this file
                checksum = nil
                FileUtils.cd(File.join(bundle_dir, druid))
                md_files = Dir.glob('**/' + filename + '.md5')
                checksum = get_checksum(File.join(bundle_dir, druid, md_files[0])) if md_files.size == 1 # we found a corresponding md5 file, read it

                xml.file(id: filename, preserve: preserve, publish: publish, shelve: shelve) do
                  xml.checksum(checksum, type: 'md5') if checksum && checksum != ''
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

    def get_role(filename)
      matches = filename.scan(/_pm|_sl|_sh/)
      if matches.empty?
        return 'Images' if ['.tif', '.tiff', '.jpg', '.jpeg', '.jp2'].include? File.extname(filename).downcase
        return 'Transcript' if ['.pdf', '.txt', '.doc'].include? File.extname(filename).downcase
        return ''
      else
        matches.first.sub('_', '').strip.upcase
      end
    end

    def get_druid(filename)
      matches = filename.scan(/[0-9a-zA-Z]{11}/)
      return '' if matches.empty?
      matches.first.strip
    end
  end
end
