# Run with
# cm=PreAssembly::Smpl.new(:bundle_dir=>'/thumpers/dpgthumper2-smpl/SC1017_SOHP',:csv_filename=>'smpl_manifest.csv',:verbose=>true)
# cm.prepare_smpl_content

# or in the context of a bundle object:
# cm=PreAssembly::Smpl.new(:csv_filename=>@content_md_creation[:smpl_manifest],:bundle_dir=>@bundle_dir,:verbose=>false)
# cm.prepare_smpl_content
# OR
# cm.generate_cm('oo000oo0001') 

module PreAssembly

    class Smpl       
       
       attr_accessor :manifest,:items,:csv_filename,:bundle_dir,:pre_md_file,:default_resource_type,:cm_type
       
       def initialize(params)
         @pre_md_file='preContentMetadata.xml'
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
    
         # load manifest into @items and then parse into @manifest hash
         @items=CsvMapper.import(@csv_filename) do read_attributes_from_file end  
        
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
                    role_folders = [role.downcase,role.upcase,role.titlecase] # look in all these combos for the MD5 files
                    checksum=nil
                    role_folders.each do |role_folder|
                      md5_file=File.join(@bundle_dir,druid,role_folder,filename + '.md5')
                      checksum = get_checksum(md5_file) if File.exists?(md5_file)
                      break if checksum # stop looking if we find one  
                    end
                      xml.file(:id=>filename,:preserve=>preserve,:publish=>publish,:shelve=>shelve) {
                         xml.checksum(checksum, :type => 'md5') if checksum && checksum != ''
                       } # end file
                  
                  end # end loop over files
                
                } # end resource
              
              end # end loop over resources

             } #end CM tag
             
           } #end XML tag
          
          return builder.to_xml
         
         else
         
           return ""
         
         end
         
       end
       
       def prepare_smpl_content

         puts "Content path: #{@bundle_dir}" if @verbose
         puts "Input spreadsheet: #{@csv_filename}"  if @verbose

         # keep track of which druid we just operated on, so we know when to start working on a new one (this is because the input CSV has more than one row per druid, but we only need one XML file per druid)
         previous_druid=''
         
         @items.each do |row|

           # if druid_no_audio exists, it will specify a druid that has no audio files, so we just need to look for extra files (images/transcripts)

           # get the druid and file extensions
           if row.druid_no_audio
             druid=row.druid_no_audio
           else
             druid=get_druid(row.filename)
             role=get_role(row.filename)
             file_extension=File.extname(row.filename)
           end

           if druid != previous_druid # we have a new druid, so let's finish up all the bits for the previous one

             if previous_druid != '' # finish up by looking for images and transcripts for this druid and then write out the previous XML file (except for the first druid)

               look_for_extra_files(@cm,@object_node,@content_folder,previous_druid)

               write_out_xml(@output_folder,@cm)

             end
             puts "*** #{druid}" if @verbose

             # generate the base of the XML file for this new druid
             @cm = Nokogiri::XML::Document.new
             @object_node = Nokogiri::XML::Node.new("object", @cm)
             @cm << @object_node
             identifiers_node = Nokogiri::XML::Node.new("identifiers", @cm)
             @object_node << identifiers_node
             ids=[]
             ids << Nokogiri::XML::Node.new("id", @cm)
             ids[0]['type']='local'
             ids[0]['name']='sourceID'
             ids[0].content=row.source_id
             identifiers_node << ids[0]
             ids << Nokogiri::XML::Node.new("id", @cm)
             ids[1]['type']='local'
             ids[1]['name']='druid'
             ids[1].content=druid
             identifiers_node << ids[1]

           end

           @content_folder=File.join(@bundle_dir,druid)   # this is the path to where the content is
           @output_folder=@content_folder     # this is the path to where we will write the resulting XML file (same as the input)

           puts "operating on '#{row.filename}' with label '#{row.label}' -- sequence '#{row.sequence}', role '#{role}'" if @verbose

           unless row.druid_no_audio
             # create the resource node for the file
             resource_node = Nokogiri::XML::Node.new("resource", @cm)
             resource_node['type']='audio'
             resource_node['role']=role.downcase
             resource_node['seq']=row.sequence if row.sequence
             label_node = Nokogiri::XML::Node.new("label", @cm)
             label_node.content=row.label
             resource_node << label_node

             @object_node << resource_node

             # create the file node and attach it to the resource node, along with supplemenatry md5 and techMD nodes
             create_file_node(resource_node,:filename=>row.filename,:druid=>druid,:role=>role.upcase,:content_folder=>@content_folder,:file_attributes=>@file_attributes[role.downcase])
           end

           # set the previous druid so we know when we are starting a new one 
           previous_druid=druid

         end

         look_for_extra_files(@cm,@object_node,@content_folder,previous_druid)

         write_out_xml(@output_folder,@cm) # write out last XML file
         
         return true

       end #prepare_smpl_content

       def get_checksum(md5_file)
         s = IO.read(md5_file)
         checksums=s.scan(/[0-9a-fA-F]{32}/)
         return checksums.first ? checksums.first.strip : ""
       end #get_checksum

       def write_out_xml(output_folder,cm)

         Dir.mkdir(output_folder) unless File.exists?(output_folder) # create the output directory if it doesn't exist

         # write out the previous druid XML file to the output directory, unless this is the first druid we are processing
         output_xml=File.join(output_folder,@pre_md_file)
         puts "****writing to #{output_xml}" if @verbose
         xml_file=File.open(output_xml,'w')
         xml_file.write cm.to_xml
         xml_file.close

       end #write_out_xml

       def look_for_extra_files(cm,object_node,content_folder,druid)

         # check to see if images folder exists, and if so, iterate and add all images as new resource nodes   
         folders=['Images','images','image','Image']
         folders.each do |folder|
           images_folder=File.join(content_folder,folder) 
           if File.exists? images_folder
             puts "found #{images_folder}" if @verbose
             FileUtils.cd(images_folder)
             Dir.glob('*').each do |image_file|
               # create the resource node for the file
               if ['.tif','.jpg','.tiff','.jpeg'].include? File.extname(image_file).downcase
                 puts "found #{image_file}" if @verbose
                 resource_node = Nokogiri::XML::Node.new("resource", cm)
                 resource_node['type']='image'
                 label_node = Nokogiri::XML::Node.new("label", cm)
                 label_node.content=get_image_label(image_file)
                 resource_node << label_node
                 create_file_node(resource_node,:filename=>image_file,:druid=>druid,:role=>'Images',:content_folder=>content_folder,:file_attributes=>@file_attributes['images'])       
                 object_node << resource_node        
               end # if found an image
             end # loop over all images
           end # folder exists
         end # loop over all input folders
         
         # check to see if transcript folder exists, and if so, iterate and add all transcripts as new resource nodes   
         
         folders=['Transcript','transcript','Transcripts','transcripts']
         folders.each do |folder|
           transcript_folder=File.join(content_folder,folder)
           if File.exists? transcript_folder
             puts "found #{transcript_folder}" if @verbose
             FileUtils.cd(transcript_folder)
             Dir.glob('*.pdf').each do |transcript_file|
               # create the resource node for the file
               puts "found #{transcript_file}" if @verbose
               resource_node = Nokogiri::XML::Node.new("resource", cm)
               resource_node['type']='text'
               label_node = Nokogiri::XML::Node.new("label", cm)
               label_node.content='Transcript'
               resource_node << label_node
               create_file_node(resource_node,:filename=>transcript_file,:druid=>druid,:role=>'Transcript',:content_folder=>content_folder,:file_attributes=>@file_attributes['transcript'])       
               object_node << resource_node        
             end # loop over transcript files
          end # folder exists
        end # loop over all folders

       end #look_for_extra_files

       def create_file_node(resource_node,params={})

         filename=params[:filename]
         file_attributes=params[:file_attributes] || {}
         filetype=params[:filetype] || 'content'
         role=params[:role]
         filerole=params[:filerole] || ''
         druid=params[:druid]
         content_folder=params[:content_folder]

         file_node = Nokogiri::XML::Node.new("file", @cm)
         file_node['type']=filetype
         file_node['id']=filename
         file_node['role']=filerole unless filerole.empty?
         unless file_attributes.empty?
           file_node['publish']=file_attributes[:publish]
           file_node['preserve']=file_attributes[:preserve]
           file_node['shelve']=file_attributes[:shelve]
         end
         location_node = Nokogiri::XML::Node.new("location", @cm)
         location_node.content="#{druid}/#{role}/#{filename}"
         file_node << location_node  

         if filetype=='content' # if we are dealing with a content filetype, check for an MD5 file and a techMD XML file and add as a additional filenodes if found

           md5_filename=filename + '.md5'
           md5_file=File.join(content_folder,role,md5_filename)
           if File.exists? md5_file
             checksum_node = Nokogiri::XML::Node.new("checksum", @cm)
             checksum_node['type']='md5'  
             checksum_node.content=get_checksum(md5_file)
             file_node << checksum_node
             create_file_node(resource_node,:filename=>md5_filename,:druid=>druid,:role=>role,:filetype=>'metadata',:filerole=>'checksum',:content_folder=>content_folder)
           end

           techmd_filename=File.basename(filename,'.*') + '_techmd.xml'
           techmd_file=File.join(content_folder,role,techmd_filename)
           if File.exists? techmd_file
             create_file_node(resource_node,:filename=>techmd_filename,:druid=>druid,:role=>role,:filetype=>'metadata',:filerole=>'techMD',:content_folder=>content_folder)
           end

         end

         resource_node << file_node

       end # create_file_node

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

       def get_image_label(filename)
         # given an image filename, find the corresponding label for the audio file based on filename rules
         audio_file_to_match=filename.gsub('_img_1','_a_sl').gsub('_img_2','_b_sl').gsub('.jpg','.mp3').gsub('.tif','.mp3')
         @items.each do |row|    
           if row.filename==audio_file_to_match
             return row.label
             break
           end
         end
         return ''
         puts '*************** NO IMAGE LABEL FOUND' if @verbose
       end # get_image_label

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
       
