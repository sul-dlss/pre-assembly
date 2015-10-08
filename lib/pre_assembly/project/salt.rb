module PreAssembly

  module Project

    module Salt

      # the name of this method must be "create_content_metadata_xml_#{content_md_creation--style}", as defined in the YAML configuration   
      
      # find a resource node that contains a file called druid.pdf ... if found, switch the resource label to something else   
       def create_content_metadata_xml_salt
           
         # otherwise use the content metadata generation gem
         params={:druid=>@druid.id,:objects=>content_object_files,:add_exif=>false,:bundle=>:filename,:style=>content_md_creation_style}
        
         params.merge!(:add_file_attributes=>true,:file_attributes=>@publish_attr.stringify_keys) unless @publish_attr.nil?
        
         content_md_xml = Assembly::ContentMetadata.create_content_metadata(params)
         
         cm_ng=Nokogiri::XML(content_md_xml)

         pdf_filename="#{@druid.id.gsub('druid:','')}.pdf"
         new_label="Document"

         pdf_file_nodes=cm_ng.css("//file[@id='#{pdf_filename}']")

         if pdf_file_nodes.size == 1 # found a PDF with the expected name, same as druid

           resource_node = pdf_file_nodes[0].parent # get the parent of the found file node
           label_nodes = resource_node.css('/label') # get the label
           label_nodes[0].content=new_label # set the new label text
        
         end
         
         return cm_ng.to_xml  
           
       end
            
    end # SALT module
      
  end # project module

end # pre-assembly module
 