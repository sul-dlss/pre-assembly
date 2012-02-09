require 'uuidtools'
require 'mini_exiftool'

module Assembly
  class Images
    
    def self.create_jp2(params={})
      
      # parameters are passed in via a hash, e.g. Assembly::Images.create_jp2(:input=>'path_to_tif.tif')
      
      # Required paramaters
      # input = full path to input TIF file
      
      # Optional parameters
      # output = full path to the output JP2 file; if not supplied, will be the same filename and path as input TIF with JP2 extension
      # allow_overwrite = true or false; if true and output JP2 exists, it will overwrite; if false, it will not; defaults to false
      # output_profile = the output color space profile to use; accetable profiles are 'sRGB' and 'AdobeRGB1998'; defaults to 'sRGB'

      begin
        
        input = params[:input] 
        unless File.exists?(input)
          puts 'input file does not exists'
          return false 
        end
      
        exif=MiniExiftool.new input
        unless exif['mimetype'] == 'image/tiff'
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
      
        pixdem = exif['imagewidth'] > exif['imageheight'] ? exif['imagewidth'] : exif['imageheight']
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
        
      end
      
    end
    
  end
end
