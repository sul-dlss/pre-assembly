module PreAssembly

  module ProjectSpecific

      def create_content_metadata_xml_smpl
        
        # if this is set to true, we will assume folder structure has been flattened during pre-assembly
        flattened_object=true
        # do not include these files in the new content metadata when creating file nodes
        file_extensions_to_exclude=%w{.md5 .xml}
                
        log "    - create_content_metadata_xml_smpl()"
        
        # create path to smpl XML content metadata
        input_cm_filename=File.join(bundle_dir,container_basename,content_md_creation[:pre_md_file])
        
        # read in smpl XML content metadata into nokogiri document
        f = File.open(input_cm_filename)
        input_xml = Nokogiri::XML(f)
        f.close
        
        # generate array of unique labels with sequences, so we know how to build resource nodes (which will be grouped by label)
        label_nodes=input_xml.xpath('//resource/label')
        labels=[]
        label_nodes.each {|label_node| labels << label_node.content}
        labels.uniq! # remove all non-unique labels, so we have a new array with the possible label values

        # generate common server prefix for location tags (which includes the full path to the server) so we can remove it when generating file ID tags, which just need to be relative
        location_nodes=input_xml.xpath('//resource/file/location').map {|location| location.content}
        server_prefix = location_nodes.first.dup
        location_nodes[1..-1].each do |e|
          server_prefix.slice!(e.size..-1) if e.size < server_prefix.size   # optimisation
          server_prefix.chop! while e.index(server_prefix) != 0
        end

        label_nodes.each {|label_node| labels << label_node.content}
        labels.uniq! # remove all non-unique labels, so we have a new array with the possible label values

        # get largest identified sequence value and set it to our beginning counter for resource nodes with no identified sequences
        sequence_values=input_xml.xpath('//resource[@seq]').xpath('@seq').map {|node| node.value.to_i}
        seq_counter=sequence_values.max
        
        # generate content metadata
        builder = Nokogiri::XML::Builder.new { |xml|
          xml.contentMetadata(node_attr_cm,:type=>'file') {  
            # iterate through each unique label, which will become a resource
            labels.each do |label|
              # grab the resource nodes with this label
              resource_nodes=input_xml.xpath("//resource[label='#{label}']")
              # grab the files nodes for this resource
              file_nodes=resource_nodes.xpath("file")
              # check to see if there is a sequence defined for this label
              sequence=resource_nodes.xpath("@seq")
              # if there is, grab the sequence value
              if sequence.size > 0 
                seq=sequence[0].value
              else # if no sequence is identified for this resource, increment our counter (which starts at the largest existing incoming sequence) and use that
                seq_counter+=1
                seq=seq_counter
              end
              xml.resource(node_attr_cm_resource(seq),:type=>'file') {
                xml.label label
                # iterate over all file nodes from input CM and create correct file nodes for this resource
                file_nodes.each do |file_node|
                  # only create file nodes when the file extension is not in our exclusion list set above
                  if file_node['id'] && !file_extensions_to_exclude.include?(File.extname(file_node['id']))
                    file_id=file_node.xpath('location')[0].content.gsub(server_prefix,'')
                    file_id=File.basename(file_id) if flattened_object # strip out the folder structure too if we are flattening the object
                    xml.file(:id=>file_id,:preserve=>file_node['preserve'],:publish=>file_node['publish'],:shelve=>file_node['shelve']) {
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