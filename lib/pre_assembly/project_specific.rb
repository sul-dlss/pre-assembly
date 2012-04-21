module PreAssembly

  module ProjectSpecific

      def create_content_metadata_xml_smpl

        #TODO deal with sequence numbers in resources if they exist
        #TODO write a spec test 
        
        log "    - create_content_metadata_xml_smpl()"
        
        # do not include these files in the new content metadata when creating file nodes
        file_extensions_to_exclude=%w{.md5 .xml}
        
        # create path to smpl XML content metadata
        input_cm_filename=File.join(bundle_dir,container_basename,content_md_creation[:pre_md_file])
        
        # read in smpl XML content metadata into nokogiri document
        f = File.open(input_cm_filename)
        input_xml = Nokogiri::XML(f)
        f.close
        
        # generate array of unique labels, so we know how to build resource nodes (which will be grouped by label)
        label_nodes=input_xml.xpath('//resource/label')
        labels=[]
        label_nodes.each {|label_node| labels << label_node.content}
        labels.uniq! # remove all non-unique labels, so we have a new array with the possible label values
        
        seq=0
        # generate content metadata
        builder = Nokogiri::XML::Builder.new { |xml|
          xml.contentMetadata(node_attr_cm,:type=>'file') {  
            # iterate through each unique label, which will become a resource
            labels.each do |label|
              seq += 1
              # grab the files nodes that have this label
              file_nodes=input_xml.xpath("//resource[label[text()='#{label}']]/file")
              xml.resource(node_attr_cm_resource(seq),:type=>'file') {
                xml.label label
                # iterate over all file nodes from input CM and create correct file nodes for this resource
                file_nodes.each do |file_node|
                  # only create file nodes when the file extension is not in our exclusion list set above
                  if file_node['id'] && !file_extensions_to_exclude.include?(File.extname(file_node['id']))
                    xml.file(:id=>file_node.xpath('location')[0].content,:preserve=>file_node['preserve'],:publish=>file_node['publish'],:shelve=>file_node['shelve']) {
                      checksum=file_node.xpath('checksum')  
                      node_provider_checksum(xml, checksum[0].content) if checksum
                    }
                  end
                end
              }
          end
          }
        }
        
        @content_md_xml = builder.to_xml
        
      end

  end

end