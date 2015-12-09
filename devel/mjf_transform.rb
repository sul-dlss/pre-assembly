# Used to transform Monterey Jazz Festival METs and MODs to contentMetadata.xml and descMetadata.xml files to prepare for pre-assembly
# August 2012
# Peter Mangiafico

# run with 'ruby devel/mjf_transform.rb'

current_path = File.dirname(File.expand_path(__FILE__))

require 'rubygems'
require 'csv'
require 'nokogiri'
require 'assembly-objectfile'
require 'csv-mapper'

content_path="/sdr-ingest/mjf-tape-all"  # **** ADD THE INPUT FOLDER PATH HERE
csv_filename=File.join(current_path,'smpl_csv','mjf_manifest.csv')   # **** ADD THE MANIFEST FILE SUPPLIED BY SMPL STAFF HERE

output_path=content_path # where to write the new files (same as input)
content_xml_filename = "contentMetadata.xml"
descriptive_xml_filename = "descMetadata.xml"

existing_files_to_remove=[content_xml_filename,descriptive_xml_filename]

# for output content metadata
content_type_description="file"
resource_type_description="file"

puts "Input spreadsheet: #{csv_filename}"
puts "Input folder: #{content_path}"
puts "Output folder: #{output_path}"
puts ""

def file_cleanup(folder,existing_files_to_remove)
  existing_files_to_remove.each do |filename|
    full_path=File.join(folder, filename)
    if File.exists?(full_path)
      puts "...Deleting existing file #{full_path}"
      File.delete(full_path)
    end
  end
end

Dir.chdir(content_path)

# read CSV
@items=CsvMapper.import(csv_filename) do read_attributes_from_file end

@items.each do |row|

  pid=row.druid
  folder=row.folder

  folder_path=File.join(content_path,folder)
  puts "Operating on #{folder}"

  file_cleanup(folder_path,existing_files_to_remove)

# dig into data subfolder
  data_folder=File.join(folder_path,"data")
  Dir.chdir(data_folder)

  # there should be one folder in there starting with "library_stanford_edu", go to it
  sub_folder=Dir.glob("library_stanford_edu*")

  if sub_folder.size == 1 # ok, we found one folder, go to it

    content_sub_folder=File.join(data_folder,sub_folder.first)
    Dir.chdir(content_sub_folder)
    puts "...Found #{content_sub_folder}"

    file_cleanup(content_sub_folder,existing_files_to_remove)

    # now find the XML file
    xml_file=Dir.glob("*.xml")

    if xml_file.size == 1 # ok we found one, grab a handle to it

      input_xml_file=File.join(content_sub_folder,xml_file.first)
      puts "...Reading #{input_xml_file}"

      f = File.open(input_xml_file)
      doc = Nokogiri::XML(f)
      f.close

      # get mods element
      mods=doc.search('//mods:mods')

      # clean up table of contents and nodes that have return characters
      mods.search('//mods:tableOfContents').each {|node| node.content=node.content.gsub('\n','&#10;')} if mods.search('//mods:tableOfContents').size !=0
      mods.search('//mods:note').each {|node| node.content=node.content.gsub('\n','&#10;')} if mods.search('//mods:note').size !=0

      # get start date and end date to see if they are the same
      start_date=mods.search('//mods:dateCreated[@point="start"]')
      end_date=mods.search('//mods:dateCreated[@point="end"]')
      if start_date.size != 0 && end_date.size != 0
        if start_date.first.content.strip == end_date.first.content.strip # if both nodes exist and are the same, just remove the end date
          mods.search('//mods:dateCreated[@point="end"]').each {|node| node.remove}
        end
      end

      # lop off any <mods:relatedItem type="constituent"> nodes
      mods.search('//mods:relatedItem[@type="constituent"]').each {|related_item_node| related_item_node.remove}

      # find file elements we need to create contentMetadata
      filesec=doc.search('fileSec')
      filegroups=filesec.search('fileGrp')

      resource_label=filesec[0].attributes['ID'].value.gsub('_',' ')

      builder = Nokogiri::XML::Builder.new do |xml|

        xml.contentMetadata(:objectId => pid,:type => content_type_description) {

          xml.resource(:id => "#{pid}-1",:sequence => "1",:type => resource_type_description) {

            xml.label resource_label

            filegroups.each do |filegroup|

              file_type=filegroup.attributes['USE'].value.strip.downcase

              files=filegroup.search('file')

              files.each do |file|

                file_location=file.search('FLocat')
                relative_path_to_file=file_location[0].attributes['href'].value.gsub('file:','') # this is the relative path to the file in the original folder structure

                id=File.basename(relative_path_to_file) # this is just the filename, used in our new contentMetadata, since we will flatten folder structure when staging during pre-assembly
                xml_file_params={:id=>id}
                xml_file_params.merge!({:mimetype=>file.attributes['MIMETYPE'].value}) unless file.attributes['MIMETYPE'].nil?
                xml_file_params.merge!({:size=>file.attributes['SIZE'].value}) unless file.attributes['SIZE'].nil?
                  case file_type
                    when 'archive masters'
                      xml_file_params.merge!({:preserve => 'yes',:publish  => 'no',:shelve   => 'no'})
                    when 'auxiliary application'
                      xml_file_params.merge!({:preserve => 'yes',:publish  => 'no',:shelve   => 'no'})
                    when 'service high'
                      xml_file_params.merge!({:preserve => 'yes',:publish  => 'no',:shelve   => 'no'})
                  end # end case file_type

                  if File.exists?(File.join(content_sub_folder,relative_path_to_file)) # this confirms the existence of the file on the original file system before adding the new node to the contentMetadata
                    xml.file(xml_file_params) {
                        xml.checksum(file.attributes['CHECKSUM'].value, :type => 'md5')
                      } # end builder file node
                  end

               end # loop over all files in a filegroup

             end # end loop over all filegroups in a filesec node

          } # end builder resource node

          # add METs resource node
          xml.resource(:id => "#{pid}-2",:sequence => "2",:type => "object") {
             xml.label "Descriptive Metadata"
             xml.file(:mimetype=>"application/tei+xml",:shelve=>"yes",:format=>"XML",:publish=>"yes",:preserve=>"yes",:id=>xml_file.first)
          }

        } # end builder contentMetadata node

      end # end builder for output content metadata

      output_xml_directory=content_sub_folder # File.join(output_path,folder)
      #Dir.mkdir(output_xml_directory) unless File.directory? output_xml_directory

      # write output contentMetadata
      output_cm=File.join(output_xml_directory, content_xml_filename)
      f=File.open(output_cm,'w') { |fh| fh.puts builder.to_xml }
      FileUtils.chmod(0644,output_cm)
      puts "...Writing #{content_xml_filename}"

      # write output descMetadata, removing blank lines
      output_dm=File.join(output_xml_directory, descriptive_xml_filename)
      f=File.open(output_dm,'w') { |fh| fh.puts mods.to_xml.gsub(/^\s*\n/, "")  }
      FileUtils.chmod(0644,output_dm)
      puts "...Writing #{descriptive_xml_filename}"

    end # end finding XML file

 else

     puts "**** ERROR: Could not locate content folder within the '#{folder}/data' folder"

   end # end check for content subfolder

end # end loop over all input rows in spreadsheet