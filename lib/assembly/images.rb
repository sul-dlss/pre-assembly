require 'uuidtools'
require 'mini_exiftool'
require 'nokogiri'
require 'Digest/sha1'
require 'Digest/md5'

module Assembly
  
  class Images

    # FORMATS is a constant used to identify the content type in the content meta-data file, 
    # it maps actual file mime/types to format attribute values in the content metadata XML file
    # see https://consul.stanford.edu/display/chimera/DOR+file+types+and+attribute+values 
     FORMATS={
       'image/jp2'=>'JPEG2000','image/jpeg'=>'JPEG','image/tiff'=>'TIFF','image/tiff-fx'=>'TIFF','image/ief'=>'TIFF','image/gif'=>'GIF',
       'text/plain'=>'TEXT','text/html'=>'HTML','text/csv'=>'CSV','audio/x-aiff'=>'AIFF','audio/x-mpeg'=>'MP3','audio/x-wave'=>'WAV',
       'video/mpeg'=>'MP2','video/quicktime'=>'QUICKTIME','video/x-msvideo'=>'AVI','application/pdf'=>'PDF','application/zip'=>'ZIP','application/xml'=>'XML',
       'application/tei+xml'=>'TEI','application/msword'=>'WORD','application/wordperfect'=>'WPD','application/mspowerpoint'=>'PPT','application/msexcel'=>'XLS',
       'application/x-tar'=>'TAR','application/octet-stream'=>'BINARY'
         }

    # Create a JP2 file from a TIF file.
    #
    # Required paramaters:
    # * full path to input TIF file
    #
    # Optional parameters (passed in via hash notation):
    # * output = full path to the output JP2 file; if not supplied, will be the same filename and path as input TIF with JP2 extension
    # * allow_overwrite = true or false; if true and output JP2 exists, it will overwrite; if false, it will not; defaults to false
    # * output_profile = the output color space profile to use; accetable profiles are 'sRGB' and 'AdobeRGB1998'; defaults to 'sRGB'
    #
    # e.g. Assembly::Images.create_jp2('path_to_tif.tif',:output=>'path_to_jp2.jp2')
    def self.create_jp2(input,params={})
      
      begin # rescue
        
        unless File.exists?(input)
          puts 'input file does not exists'
          return false 
        end
      
        exif=MiniExiftool.new input
        unless exif.mimetype == 'image/tiff'
          puts 'input file was not TIFF'
          return false
        end
    
        output = params[:output] || input.gsub(File.extname(input),'.jp2') 
        allow_overwrite=params[:allow_overwrite] || false

        if !allow_overwrite && File.exists?(output)
          puts "output #{output} exists, cannot overwrite"
          return false
        end
      
        output_profile=params[:output_profile] || 'sRGB'
        path_to_profiles=File.join(Assembly::PATH_TO_GEM,'profiles')
        
        output_profile_file=File.join(path_to_profiles,"#{output_profile}.icc")
      
        if !File.exists?(output_profile_file)
          puts "output profile #{output_profile} invalid"
          return false       
        end

        path_to_profiles=File.join(Assembly::PATH_TO_GEM,'profiles')

        input_profile=exif['profiledescription'].nil? ? "" : exif['profiledescription'].gsub(/[^[:alnum:]]/, '') # remove all non alpha-numeric characters, so we can get to a filename
        input_profile_file=File.join(path_to_profiles,"#{input_profile}.icc")

        # make temp tiff
        temp_tif_file="/tmp/#{UUIDTools::UUID.random_create.to_s}.tif"
        profile_conversion=File.exists?(input_profile_file) ? "-profile #{input_profile_file} -profile #{output_profile_file}" : ""        
        tiff_command = "convert -quiet -compress none #{profile_conversion} #{input} #{temp_tif_file}"
        system(tiff_command)
      
        pixdem = exif.imagewidth > exif.imageheight ? exif.imagewidth : exif.imageheight
        layers = (( Math.log(pixdem) / Math.log(2) ) - ( Math.log(96) / Math.log(2) )).ceil + 1

        # Start jp2 creation section
        kdu_bin = "kdu_compress "
        options = " -precise -no_weights -quiet Creversible=no Cmodes=BYPASS Corder=RPCL Cblk=\\{64,64\\} Cprecincts=\\{256,256\\},\\{256,256\\},\\{128,128\\} ORGgen_plt=yes -rate 1.5 Clevels=5 "
        jp2_command = "#{kdu_bin} #{options} Clayers=#{layers.to_s} -i #{temp_tif_file} -o #{output}"
        system(jp2_command)
      
        File.delete(temp_tif_file)
      
        return true
        
      rescue Exception => error
        
        puts "error: #{error}"
        return false        
        
      end # rescue 
      
    end # create_jp2

    # Generate image content metadata files given a set of files as an array of arrays.  This method only produces content metadata for
    # images and does not depend on a specific folder structure.
    #    
    # Required parameters:
    # * druid = the string of the druid
    # * file_set = an array of arrays of files to generate content metadata_for
    # * content_label = a label that will be added to the content metadata
    # * policy = a hash of APO level policies
    # e.g. Assembly::Images.create_content_metadata('nx288wh8889',['file1.tif','file1.jp2'],['file2.tif','file2.jp2'])
    def self.create_content_metadata(druid,file_set,content_label="",policy={})
      
      content_type_description="image"
      sequence=0

      publish= policy[:publish] || {'TIFF' => 'no',  'JPEG2000' => 'yes', 'JPEG'=> 'yes'}  # indicates if content in metadata XML file will be marked as publish
      preserve= policy[:preserve] || {'TIFF' => 'yes', 'JPEG2000' => 'yes', 'JPEG' => 'yes'}  # indicates if content in metadata XML file will be marked as preserve
      shelve= policy[:shelve] || {'TIFF' => 'no', 'JPEG2000' => 'yes', 'JPEG' => 'yes'}  # indicates if content in metadata XML file will be marked as shelve
    
      builder = Nokogiri::XML::Builder.new do |xml|
           xml.contentMetadata(:objectId=>"#{druid}",:type=>content_type_description) {
             file_set.each do |entry| # iterate over all of the input file sets
               sequence+=1
               resource_id="#{druid}_#{sequence}"
               # start a new resource element
               xml.resource(:id=>resource_id,:sequence=>sequence,:type=>content_type_description) {
                 xml.label content_label
                 entry.each do |filename| # iterate over the first set of files
                    id=filename
                    exif=MiniExiftool.new(filename)
                    mimetype=exif.mimetype
                    size=exif.filesize.to_i
                    width=exif.imagewidth
                    height=exif.imageheight
                    md5 = Digest::MD5.new
                    sha1 = Digest::SHA1.new
                    File.open(filename, 'rb') do |io|
                      buffer = ''
                      while io.read(4096,buffer)
                          md5.update(buffer)
                          sha1.update(buffer)
                      end
                    end
                    format=FORMATS[mimetype.downcase]                      
                    cropped="uncropped"
                    # add a new file element to the XML for this file
                    xml.file(:publish=>publish[format],:format=>format,:id=>id,:mimetype=>mimetype,:preserve=>preserve[format],:shelve=>shelve[format],:size=>size) {
                      xml.imageData(:height=>height,:width=>width)
                      xml.attr cropped,:name=>'representation'
                      xml.checksum sha1,:type=>'sha1'
                      xml.checksum md5,:type=>'md5'
                    }
                 end # end loop over all specified content types for a given file in the base content directory
               }
               end # end loop over base content directory
             }
       end
       return builder.to_xml
      
    end # create_content_metadata
    
  end # image

end # assembly
