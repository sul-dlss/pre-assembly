# run with ruby devel/retrieve_content.rb
# must be run from lyberservices-prod to have access to all mounts and configuration

#!/usr/bin/env ruby
ENV['ROBOT_ENVIRONMENT']='production'  # environment to run under (i.e. which fedora instance to hit)

# search possible locations for object (new and old style)
def path_to_object(druid)
  DruidTools::Druid.new(druid,Dor::Config.content.content_base_dir).path() 
end

def content_folder(druid)
  File.join(path_to_object(druid),'content')
end

def metadata_folder(druid)
  File.join(path_to_object(druid),'metadata')
end

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')

require 'pp'
require 'rubygems'
require 'dor-services'
require 'assembly-utils'
require 'logger'

@druids=%w{
  druid:ws012nq5164
  druid:sd586gp3826
}
         
@druids.each do |druid|

  @fobj=Dor::Item.find(druid)
  puts "working on #{druid}"
  
  # create directories in /dor/workspace if they do not exist
  FileUtils.mkpath(path_to_object(druid)) unless File.directory?(path_to_object(druid))
  FileUtils.mkpath(content_folder(druid)) unless File.directory?(content_folder(druid))
  FileUtils.mkpath(metadata_folder(druid)) unless File.directory?(metadata_folder(druid))

  # write out content metadata from object unless a version already exists in the directory
  cm_file=File.join(metadata_folder(druid),'contentMetadata.xml')
  unless File.exists?(cm_file)
    File.open(cm_file, 'w') { |fh| fh.puts @fobj.contentMetadata.ng_xml.to_s }
    puts 'write contentMetadata.xml'
  end
  
  # figure out where the source content is (assuming only ludvigsen here)
  source_id=@fobj.identityMetadata.sourceId
  base_content_directory='/dor/staging/Revs/Ludvigsen/'
  content_subfolder=/LUDV-\d\d\d\d/.match(source_id).to_s.gsub('-','_')
  filename="#{source_id}.tif".gsub('Revs:','')
  source=File.join(base_content_directory,content_subfolder,filename)
  dest=File.join(content_folder(druid),filename)
  
  FileUtils.cp(source,dest) unless File.exists?(dest) && !File.exists?(source)

end         