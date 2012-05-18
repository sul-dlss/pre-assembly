module PreAssembly

  module ProjectSpecific

      def create_content_metadata_xml_smpl
        
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
 
        # get largest identified sequence value and set it to our beginning counter for resource nodes with no identified sequences
        sequence_values=input_xml.xpath('//resource[@seq]').xpath('@seq').map {|node| node.value.to_i}
        seq_counter=sequence_values.max || 0
        
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
                    file_id=File.basename(file_node.xpath('location')[0].content) 
                    xml.file(:id=>file_id,:preserve=>file_node['preserve'],:publish=>file_node['publish'],:shelve=>file_node['shelve']) {
                      checksum=file_node.xpath('checksum')  
                      node_provider_checksum(xml, checksum[0].content) unless checksum.blank?
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