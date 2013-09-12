# Run with
# cm=PreAssembly::Smpl.new(:bundle_dir=>'/thumpers/dpgthumper2-smpl/SC1017_SOHP',:csv_filename=>'smpl_manifest.csv')
# cm.prepare_smpl_content

# or in the context of a bundle object:
# cm=PreAssembly::Smpl.new(:csv_filename=>@content_md_creation[:smpl_manifest],:bundle_dir=>@bundle_dir,:pre_md_file=>@content_md_creation[:pre_md_file],:verbose=>false)
# cm.prepare_smpl_content

module PreAssembly

    class Smpl       
       
       attr_accessor :manifest,:items,:csv_filename,:bundle_dir,:pre_md_file
       
       def initialize(params)
         @pre_md_file=params[:pre_md_file] || 'preContentMetadata.xml'
         @bundle_dir=params[:bundle_dir]
         csv_file=params[:csv_filename] || 'smpl_manifest.csv'
         @csv_filename=File.join(@bundle_dir,csv_file)
         @verbose=params[:verbose] || true
         
         @file_attributes={}
         @file_attributes['pm']={:publish=>'no',:shelve=>'no',:preserve=>'yes'}
         @file_attributes['sh']={:publish=>'no',:shelve=>'no',:preserve=>'yes'}
         @file_attributes['sl']={:publish=>'yes',:shelve=>'yes',:preserve=>'yes'}
         @file_attributes['image']={:publish=>'yes',:shelve=>'yes',:preserve=>'yes'}
         @file_attributes['text']={:publish=>'yes',:shelve=>'yes',:preserve=>'yes'}
         
       end
       
       def load_manifest
    
         # load manifest into @items and then parse into @manifest hash
         @items=CsvMapper.import(@csv_filename) do read_attributes_from_file end  
        
         @manifest={}
                  
         @items.each do |row|
            
            if row.druid_no_audio
              druid=row.druid_no_audio
            else
              druid=get_druid(row.filename)
              role=get_role(row.filename)
              file_extension=File.extname(row.filename)
            end
            
            manifest[druid]={:source_id=>'',:files=>[]} if manifest[druid].nil?
            manifest[druid][:source_id]=row.source_id if row.source_id
            manifest[druid][:files] << {:role=>role,:file_extention=>file_extension,:filename=>row.filename,:label=>row.label,:sequence=>row.sequence}
            
         end # loop over all items
         
       end # load_manifest
       
       def prepare_smpl_content

         puts "Content path: #{@bundle_dir}" if @verbose
         puts "Input spreadsheet: #{@csv_filename}"  if @verbose

         # keep track of which druid we just operated on, so we know when to start working on a new one (this is because the input CSV has more than one row per druid, but we only need one XML file per druid)
         previous_druid=''

         # read CSV
         load_manifest
         
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
         return checksums.first.strip
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
                 create_file_node(resource_node,:filename=>image_file,:druid=>druid,:role=>'Images',:content_folder=>content_folder,:file_attributes=>@file_attributes['image'])       
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
               create_file_node(resource_node,:filename=>transcript_file,:druid=>druid,:role=>'Transcript',:content_folder=>content_folder,:file_attributes=>@file_attributes['text'])       
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
           return ""
         else
           matches.first.sub('_','').strip
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
       
