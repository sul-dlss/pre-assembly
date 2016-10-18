# encoding: UTF-8

# This class generates contentMetadata from a SMPL supplied manifest
# see the "SMPL Content" section here for a description of the manifest:
# https://consul.stanford.edu/pages/viewpage.action?pageId=136365158#AutomatedAccessioningandObjectRemediation(pre-assemblyandassembly)-SMPLContent

# It is used by pre-assembly during the accessioning process in an automated way based on the pre-assembly config .yml file setting of content_md_creation

# Test with
# cm=PreAssembly::Smpl.new(:bundle_dir=>'/thumpers/dpgthumper2-smpl/ARS0022_speech/content_ready_for_accessioning/content',:csv_filename=>'smpl_manifest.csv',:verbose=>true)
# cm.generate_cm('zx248jc1918')

# or in the context of a bundle object:
# cm=PreAssembly::Smpl.new(:csv_filename=>@content_md_creation[:smpl_manifest],:bundle_dir=>@bundle_dir,:verbose=>false)
# cm.generate_cm('oo000oo0001')


module PreAssembly

    class Smpl

      include PreAssembly::Logging

       attr_accessor :manifest,:rows,:csv_filename,:bundle_dir,:default_resource_type,:cm_type

       def initialize(params)
         @bundle_dir=params[:bundle_dir]
         csv_file=params[:csv_filename] || 'smpl_manifest.csv'
         @csv_filename=File.join(@bundle_dir,csv_file)
         @verbose=params[:verbose] || false

         # default publish/shelve/preserve attributes per "type" as defined in smpl filenames
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
         load_manifest # this will cache the entire manifest in @rows and @manifest

         puts "found #{@rows.size} rows in manifest" if @verbose

       end

       def load_manifest

         # load file into @rows and then build up @manifest
         @rows=PreAssembly::Bundle.import_csv(@csv_filename)

         @manifest={}

         @rows.each do |row|

            druid=get_druid(row[:filename])
            role=get_role(row[:filename])
            file_extension=File.extname(row[:filename])
            # set the resource type if available, otherwise we'll use a default
            resource_type=defined?(row[:resource_type]) ? row[:resource_type] || nil : nil

            # set the thumb attribute for this resource if it is set in the manifest to true, yes or thumb (set to false if no value or column is missing)
            thumb=(defined?(row[:thumb]) && row[:thumb] && ['true','yes','thumb'].include?(row[:thumb].downcase)) ? true : false

            # set the publish/preserve/shelve if available, otherwise we'll use the defaults
            publish=defined?(row[:publish]) ? row[:publish] || nil : nil
            shelve=defined?(row[:shelve]) ? row[:shelve] || nil : nil
            preserve=defined?(row[:preserve]) ? row[:preserve] || nil : nil

            @manifest[druid]={:source_id=>'',:files=>[]} if manifest[druid].nil?
            @manifest[druid][:source_id]=row[:source_id] if (defined?(row[:source_id]) && row[:source_id])
            @manifest[druid][:files] << {:thumb=>thumb,:publish=>publish,:shelve=>shelve,:preserve=>preserve,:resource_type=>resource_type,:role=>role,:file_extention=>file_extension,:filename=>row[:filename],:label=>row[:label],:sequence=>row[:sequence]}
            
         end # loop over all rows

       end # load_manifest

       # actually generate content metadata for a specific druid in the manifest
       def generate_cm(druid)

         pid=druid.gsub!('druid:','')

         if @manifest[druid]

           current_directory=Dir.pwd

           files=@manifest[druid][:files]
           source_id=@manifest[druid][:source_id]

           current_seq = ''
           resources={}

           # bundle the files into resources based on the sequence # defined in the manifest, a new sequence number triggers a new resource
           files.each do |file|
             seq=file[:sequence]
             label=file[:label] || ""
             resource_type=file[:resource_type] || @default_resource_type
             if (!seq.nil? && seq != '' && seq != current_seq) # this is a new resource if we have a non-blank different sequence number
               resources[seq.to_i] = {:label=>label,:sequence=>seq,:resource_type=>resource_type,:files=>[]}
               current_seq = seq
             end
             resources[current_seq.to_i][:files] << file
             resources[current_seq.to_i][:thumb]=file[:thumb] if file[:thumb] # any true/yes thumb attribute for any file in that resource triggers the whole resource as thumb=true
           end
  
           # generate the base of the XML file for this new druid
           # generate content metadata
           builder = Nokogiri::XML::Builder.new { |xml|

             xml.contentMetadata(:objectId => druid,:type=>@cm_type) {

              resources.keys.sort.each do |seq|
                resource=resources[seq]
                resource_attributes={:sequence => seq.to_s, :id => "#{druid}_#{seq}",:type=>resource[:resource_type]}
                resource_attributes[:thumb]='yes' if resource[:thumb] # add the thumb=yes attribute to the resource if it was marked that way in the manifest
                xml.resource(resource_attributes) {
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

       end # end generate_cm

       def get_checksum(md5_file)
         s = IO.read(md5_file)
         checksums=s.scan(/[0-9a-fA-F]{32}/)
         checksums.first ? checksums.first.strip : ""
       end # end get_checksum


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
       end # end get_role

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

