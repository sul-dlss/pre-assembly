require 'uuidtools'
require 'mini_exiftool'
require 'nokogiri'
require 'Digest/sha1'
require 'Digest/md5'

module Assembly
  
  class Images

    # See https://consul.stanford.edu/display/chimera/DOR+file+types+and+attribute+values.
    FORMATS = {
      # MIME type.               => The format attribute in the content metadata XML file.
      'image/jp2'                => 'JPEG2000',
      'image/jpeg'               => 'JPEG',
      'image/tiff'               => 'TIFF',
      'image/tiff-fx'            => 'TIFF',
      'image/ief'                => 'TIFF',
      'image/gif'                => 'GIF',
      'text/plain'               => 'TEXT',
      'text/html'                => 'HTML',
      'text/csv'                 => 'CSV',
      'audio/x-aiff'             => 'AIFF',
      'audio/x-mpeg'             => 'MP3',
      'audio/x-wave'             => 'WAV',
      'video/mpeg'               => 'MP2',
      'video/quicktime'          => 'QUICKTIME',
      'video/x-msvideo'          => 'AVI',
      'application/pdf'          => 'PDF',
      'application/zip'          => 'ZIP',
      'application/xml'          => 'XML',
      'application/tei+xml'      => 'TEI',
      'application/msword'       => 'WORD',
      'application/wordperfect'  => 'WPD',
      'application/mspowerpoint' => 'PPT',
      'application/msexcel'      => 'XLS',
      'application/x-tar'        => 'TAR',
      'application/octet-stream' => 'BINARY',
    }

    def initialize
      # TODO: pass in needed parameters.
    end

    # Create a JP2 file from a TIF file.
    #
    # Required paramaters:
    #   * input = path to input TIF file
    #
    # Optional parameters:
    #   * output          = path to the output JP2 file (default: mirrors the TIF file name)
    #   * allow_overwrite = an existing JP2 file won't be overwritten unless this is true
    #   * output_profile  =  output color space profile: either sRGB (the default) or AdobeRGB1998    
    def create_jp2(input, params = {})

      begin

        unless File.exists?(input)
          puts 'input file does not exists'
          return false
        end

        exif = MiniExiftool.new input
        unless exif.mimetype == 'image/tiff'
          puts 'input file was not TIFF'
          return false
        end

        output          = params[:output] || input.gsub(File.extname(input),'.jp2')
        allow_overwrite = params[:allow_overwrite] || false

        if !allow_overwrite && File.exists?(output)
          puts "output #{output} exists, cannot overwrite"
          return false
        end

        output_profile      = params[:output_profile] || 'sRGB'
        path_to_profiles    = File.join(Assembly::PATH_TO_GEM,'profiles')
        output_profile_file = File.join(path_to_profiles,"#{output_profile}.icc")

        if !File.exists?(output_profile_file)
          puts "output profile #{output_profile} invalid"
          return false
        end

        path_to_profiles   = File.join(Assembly::PATH_TO_GEM,'profiles')
        # remove all non alpha-numeric characters, so we can get to a filename
        input_profile      = exif['profiledescription'].nil? ? "" :
                             exif['profiledescription'].gsub(/[^[:alnum:]]/, '')
        input_profile_file = File.join(path_to_profiles,"#{input_profile}.icc")

        # make temp tiff
        temp_tif_file      = "/tmp/#{UUIDTools::UUID.random_create.to_s}.tif"
        profile_conversion = File.exists?(input_profile_file) ?
                             "-profile #{input_profile_file} -profile #{output_profile_file}" : ""
        tiff_command       = "convert -quiet -compress none #{profile_conversion} #{input} #{temp_tif_file}"
        system(tiff_command)

        pixdem = exif.imagewidth > exif.imageheight ? exif.imagewidth : exif.imageheight
        layers = (( Math.log(pixdem) / Math.log(2) ) - ( Math.log(96) / Math.log(2) )).ceil + 1

        # Start jp2 creation section
        kdu_bin     = "kdu_compress "
        options     = " -precise -no_weights -quiet Creversible=no Cmodes=BYPASS Corder=RPCL " + 
                      "Cblk=\\{64,64\\} Cprecincts=\\{256,256\\},\\{256,256\\},\\{128,128\\} " + 
                      "ORGgen_plt=yes -rate 1.5 Clevels=5 "
        jp2_command = "#{kdu_bin} #{options} Clayers=#{layers.to_s} -i #{temp_tif_file} -o #{output}"
        system(jp2_command)

        File.delete(temp_tif_file)

        return true

      rescue Exception => error
        puts "error: #{error}"
        return false
      end

    end # create_jp2()

    # Generates image content XML metadata for a repository object.
    # This method only produces content metadata for images
    # and does not depend on a specific folder structure.
    #
    # Required parameters:
    #   * druid     = the repository object's druid id as a string
    #   * file_sets = an array of arrays of files
    #
    # Optional parameters:
    #   * content_label = label that will be added to the content metadata (default = '')
    #   * publish       = hash specifying content types to be published
    #   * preserve      = ...                                 preserved
    #   * shelve        = ...                                 shelved
    #
    # For example:
    #    create_content_metadata(
    #      'nx288wh8889',
    #      [ ['foo.tif', 'foo.jp2'], ['bar.tif', 'bar.jp2'] ],
    #      :content_label => 'Collier Collection',
    #      :preserve      => { 'TIFF'=>'yes', 'JPEG2000' => 'no'},
    #    )
    def create_content_metadata(druid, file_sets, params={})

      content_type_description = "image"

      publish       = params[:publish]       || {'TIFF' => 'no',  'JPEG2000' => 'yes', 'JPEG' => 'yes'}
      preserve      = params[:preserve]      || {'TIFF' => 'yes', 'JPEG2000' => 'yes', 'JPEG' => 'yes'}
      shelve        = params[:shelve]        || {'TIFF' => 'no',  'JPEG2000' => 'yes', 'JPEG' => 'yes'}
      content_label = params[:content_label] || ''

      file_sets.flatten.each {|file| return false if !File.exists?(file)}

      sequence = 0

      builder = Nokogiri::XML::Builder.new do |xml|
        xml.contentMetadata(:objectId => "#{druid}",:type => content_type_description) {
          file_sets.each do |file_set|
            sequence += 1
            resource_id = "#{druid}_#{sequence}"
            # start a new resource element
            xml.resource(:id => resource_id,:sequence => sequence,:type => content_type_description) {
              xml.label content_label
              file_set.each do |filename|
                id       = filename
                exif     = MiniExiftool.new(filename)
                mimetype = exif.mimetype
                size     = exif.filesize.to_i
                width    = exif.imagewidth
                height   = exif.imageheight
                md5      = Digest::MD5.new
                sha1     = Digest::SHA1.new
                File.open(filename, 'rb') do |io|
                  buffer = ''
                  while io.read(4096,buffer)
                    md5.update(buffer)
                    sha1.update(buffer)
                  end
                end
                format  = FORMATS[mimetype.downcase]
                cropped = "uncropped"
                # add a new file element to the XML for this file
                xml_file_params = {
                  :publish  => publish[format],
                  :format   => format,
                  :id       => id,
                  :mimetype => mimetype,
                  :preserve => preserve[format],
                  :shelve   => shelve[format],
                  :size     => size
                }
                xml.file(xml_file_params) {
                  xml.imageData(:height => height, :width => width)
                  xml.attr cropped, :name => 'representation'
                  xml.checksum sha1, :type => 'sha1'
                  xml.checksum md5, :type => 'md5'
                }
              end # file_set.each
            }
          end # file_sets.each
        }
      end
      return builder.to_xml

    end # create_content_metadata()

    # TODO: replace this method with real code.
    @@master_druid = 'aa000aa0000'
    def spawn_druid
      @@master_druid.next!
    end

  end # class Images


  class Bundle

    def initialize(manifest, expected_checksums)
      @manifest           = manifest
      @expected_checksums = expected_checksums
      
    end

  end # class Bundle


  # Maybe class ImageInfo << FileInfo
  class FileInfo

  end # class FileInfo


  class DigitalObject

  end # class DigitalObject


end # module Assembly
