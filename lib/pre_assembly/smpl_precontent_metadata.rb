# encoding: UTF-8

# Run with
# cm=PreAssembly::Smpl.new(:bundle_dir=>'/thumpers/dpgthumper2-smpl/ARS0022_speech/content_ready_for_accessioning/content',:csv_filename=>'smpl_manifest.csv',:verbose=>true)
# cm.generate_cm('zx248jc1918')

# or in the context of a bundle object:
# cm=PreAssembly::Smpl.new(:csv_filename=>@content_md_creation[:smpl_manifest],:bundle_dir=>@bundle_dir,:verbose=>false)
# cm.generate_cm('oo000oo0001') 

module PreAssembly

    class Smpl       
       
       attr_accessor :manifest,:items,:csv_filename,:bundle_dir,:default_resource_type,:cm_type
       
       def initialize(params)
         @bundle_dir=params[:bundle_dir]
         csv_file=params[:csv_filename] || 'smpl_manifest.csv'
         @csv_filename=File.join(@bundle_dir,csv_file)
         @verbose=params[:verbose] || false
         
         @file_attributes={}
         @file_attributes['default']={:publish=>'no',:shelve=>'no',:preserve=>'yes'}
         @file_attributes['pm']={:publish=>'no',:shelve=>'no',:preserve=>'yes'}
         @file_attributes['sh']={:publish=>'no',:shelve=>'no',:preserve=>'yes'}
         @file_attributes['sl']={:publish=>'yes',:shelve=>'yes',:preserve=>'yes'}
         @file_attributes['images']={:publish=>'yes',:shelve=>'yes',:preserve=>'yes'}
         @file_attributes['transcript']={:publish=>'yes',:shelve=>'yes',:preserve=>'yes'}
        
         @default_resource_type="media"
         @cm_type="media"
         
         # read CSV
         load_manifest
         
         puts "found #{@items.size} items in manifest" if @verbose

       end
       
       def load_manifest
    
         # load manifest into @items
         @items=PreAssembly::Bundle.import_csv_to_structs(@csv_filename)

         @manifest={}
                  
         @items.each do |row|
            
            if (defined?(row.druid_no_audio) && row.druid_no_audio) # this column doesn't need to exist anymore, but we'll leave it here for backwards compatibility
              druid=row.druid_no_audio
            else
              druid=get_druid(row.filename)
              role=get_role(row.filename)
              file_extension=File.extname(row.filename)
              # set the resource type if available, otherwise we'll use a default
              resource_type=defined?(row.resource_type) ? row.resource_type || nil : nil    

              # set the publish/preserve/shelve if available, otherwise we'll use the default
              publish=defined?(row.publish) ? row.publish || nil : nil
              shelve=defined?(row.shelve) ? row.shelve || nil : nil
              preserve=defined?(row.preserve) ? row.preserve || nil : nil
            end
            
            manifest[druid]={:source_id=>'',:files=>[]} if manifest[druid].nil?
            manifest[druid][:source_id]=row.source_id if (defined?(row.source_id) && row.source_id)
            manifest[druid][:files] << {:publish=>publish,:shelve=>shelve,:preserve=>preserve,:resource_type=>resource_type,:role=>role,:file_extention=>file_extension,:filename=>row.filename,:label=>row.label,:sequence=>row.sequence}
            
         end # loop over all items
         
       end # load_manifest
       
        # generate content metadata for a specific druid in the manifest
       def generate_cm(druid)
         
         load_manifest if @manifest.nil?
         
         druid.gsub!('druid:','')
         
         if @manifest[druid]

           current_directory=Dir.pwd
           
           files=@manifest[druid][:files]
           source_id=@manifest[druid][:source_id]
                  
           current_seq = ''
           resources={}

           # bundle into resources based on sequence
           files.each do |file|
             seq=file[:sequence]
             label=file[:label] || ""
             resource_type=file[:resource_type] || @default_resource_type
             if (!seq.nil? && seq != '' && seq != current_seq) # this is a new resource if we have a non-blank different sequence number
               resources[seq.to_i] = {:label=>label,:sequence=>seq,:resource_type=>resource_type,:files=>[]}   
               current_seq = seq
             end
             resources[current_seq.to_i][:files] << file
           end
          
           # generate the base of the XML file for this new druid
           # generate content metadata
           builder = Nokogiri::XML::Builder.new { |xml|
             
             xml.contentMetadata(:objectId => druid,:type=>@cm_type) {  

              resources.keys.sort.each do |seq|
                resource=resources[seq]
                xml.resource(:sequence => seq.to_s, :id => "#{druid}_#{seq}",:type=>resource[:resource_type]) {
                  xml.label resource[:label]  
                
                  resource[:files].each do |file|
                    filename=file[:filename] || ""
                    role=file[:role]
                    file_attributes=@file_attributes[role.downcase] || @file_attributes['default']
                    
                    publish=file[:publish] || file_attributes[:publish] || "true"
                    preserve=file[:preserve] || file_attributes[:preserve] || "true"
                    shelve=file[:shelve] || file_attributes[:shelve] || "true"

                    # look for a checksum file named the same as this file
                    checksum=nil                    
                    FileUtils.cd(File.join(@bundle_dir,druid))
                    md_files=Dir.glob("**/" + filename + ".md5")
                    checksum = get_checksum(File.join(@bundle_dir,druid,md_files[0])) if md_files.size == 1 # we found a corresponding md5 file, read it

                    xml.file(:id=>filename,:preserve=>preserve,:publish=>publish,:shelve=>shelve) {
                       xml.checksum(checksum, :type => 'md5') if checksum && checksum != ''
                     } # end file
                  
                  end # end loop over files
                
                } # end resource
              
              end # end loop over resources

             } #end CM tag
             
           } #end XML tag
         
          FileUtils.cd(current_directory)
            
          return builder.to_xml
         
         else # no druid found in mainfest
         
           return ""
         
         end # end if druid found in manifest
                  
       end # generate_cm
       
       
       def get_checksum(md5_file)
         s = IO.read(md5_file)
         checksums=s.scan(/[0-9a-fA-F]{32}/)
         return checksums.first ? checksums.first.strip : ""
       end #get_checksum


       def get_role(filename)
         matches=filename.scan(/_pm|_sl|_sh/)  
         if matches.size==0 
           if ['.tif','.tiff','.jpg','.jpeg','.jp2'].include? File.extname(filename).downcase
             return 'Images'
            elsif ['.pdf','.txt','.doc'].include? File.extname(filename).downcase
              return "Transcript"
            else
             return ""
            end
         else
           matches.first.sub('_','').strip.upcase
         end
       end # get_role


       def get_druid(filename)
         matches=filename.scan(/[0-9a-zA-Z]{11}/)
         if matches.size==0 
           return ""
         else
           matches.first.strip
         end
       end # get_druid
    
    end # Smpl class
  
end # preassembly module  
       
