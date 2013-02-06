# run with ruby devel/add_and_update_files.rb

#!/usr/bin/env ruby
ENV['ROBOT_ENVIRONMENT']='test'  # environment to run under (i.e. which fedora instance to hit)

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')
current_path = File.dirname(File.expand_path(__FILE__))

@base_path = '/tmp' # path where new files are located
publish="yes"  # values for new files that need to be added
preserve="yes"
shelve="yes"

objects=[
  {:druid=>'druid:bc001rm4583',:filename=>'2011-014HEWI-1955-b1_10.11_0001.tif'},
  {:druid=>'druid:bc104bp6427',:filename=>'2011-014HEWI-1954-b1_4.4_0002.tif'},
  {:druid=>'druid:bc104yg4412',:filename=>'bogus_name.tif'}
  ] # list of druids and filesnames to act on

require 'rubygems'
require 'dor-services'
require 'assembly-utils'
require 'logger'

objects.each do |object|

  druid=object[:druid]
  file_name=object[:filename]   # name of file to add or replace
  
  path_to_new_file=File.join(@base_path,file_name)

  unless File.exists? path_to_new_file
    
    puts "#{path_to_new_file} not found" 
  
  else # we have our new file
    
    file=File.new(path_to_new_file)
    
    objectfile=Assembly::ObjectFile.new(path_to_new_file)
    md5=objectfile.md5
    sha1=objectfile.sha1
    size=objectfile.filesize
    file_hash={:name=>file_name,:md5 => md5, :size=>size.to_s, :sha1=>sha1}
    
    item=Dor::Item.find(druid)

    druid_tools=DruidTools::Druid.new(item.pid,Dor::Config.content.content_base_dir)
    replacement_file_location=druid_tools.path(file_name)
    
    file_nodes=item.contentMetadata.ng_xml.search("//file[@id='#{file_name}']")

    if file_nodes.size == 1 # file already exists in object

      # replace it
      puts "#{file_name} found in #{druid}"
      
      FileUtils.rm(replacement_file_location)
      FileUtils.cp(path_to_new_file,replacement_file_location)
      
      item.contentMetadata.update_file(file_hash, file_name)
      puts item.contentMetadata.to_xml
      puts file_hash
      # item.publish_metadata
      # item.shelve
      
    else # file does not exist in object

      # add it 
      puts "#{file_name} not found in #{druid}"
     
      file_hash.merge!({:publish=>publish,:shelve=> shelve,:preserve => preserve,:mime_type => objectfile.mimetype})

      FileUtils.cp(path_to_new_file,replacement_file_location)

      # TODO Get resource ID to add new file node in
      resource="bc104yg4412_1"
      
      item.contentMetadata.add_file(file_hash,resource)
      puts item.contentMetadata.to_xml

      # item.publish_metadata
      # item.shelve
            
    end
  
  end
  
end