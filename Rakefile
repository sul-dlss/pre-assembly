#require "bundler/gem_tasks"
require 'csv'
require 'nokogiri'

desc "Convert incoming spreadsheet from SMPL into XML file that will be produced.  Should only be temporarily needed until final XML is delivered."
task :prepare_smpl_content, :content_path, :csv_filename do |t, args|
  
  content_path = args[:content_path] || '/path'
  csv_filename = args[:csv_filename] || 'tmp/smpl.csv'
  puts "Content path: #{content_path}"
  puts "Input spreadsheet: #{csv_filename}"
  
  CSV.foreach(csv_filename) do |row|
    filename=row[0]
    label=row[1]
    puts "operating on '#{filename}' with label '#{label}'"
    
    filename_parts=filename.split('_')
    druid=filename_parts(0)
    file_extension=File.extname(filename)
    
    builder = Nokogiri::XML::Builder.new { |xml|
      xml.contentMetadata(:objectId => @druid.id) {
        @images.each_with_index { |img, i|
          seq = i + 1
          xml.resource(:sequence => seq, :id => "#{@druid.id}_#{seq}") {
            file_params = { :id => img.file_name }.merge @publish_attr
            xml.label "Item #{seq}"
            xml.file(file_params) {
              xml.provider_checksum img.exp_md5, :type => 'md5'
            }
          }
        }
      }
    }
    xml_file=File.open(File.join(get_workspace_directory,filename),'w')
    xml_file.write builder.to_xml
    xml_file.close
    
  end
  
  
end