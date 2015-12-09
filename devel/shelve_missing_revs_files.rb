# publish and shelve missing files for Revs

# run with ruby devel/shelve_missing_revs_files.rb
# must be run from lyberservices-prod to have access to all mounts and configuration

#!/usr/bin/env ruby
ENV['ROBOT_ENVIRONMENT']='production'  # environment to run under (i.e. which fedora instance to hit)

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')

require 'rubygems'
require 'dor-services'
require 'net/ssh'

# input is a hash, druids as keys, image filenames as values ... missing jp2 files are in path indicated at the beginning of the script
druids={
'druid:cz932py8841'=>['2006-001PHIL-1957-b1_29.0_0026.jp2'],
'druid:qh240gj0159'=>['2006-001PHIL-1957-b1_65.0_0011.jp2'],
'druid:dq390fd5990'=>['2006-001PHIL-1963-b1_43.2_0021.jp2'],
'druid:dm295pp9644'=>['2006-001PHIL-1960-b1_17.0_0003.jp2'],
'druid:pb529hd7570'=>['2006-001PHIL-1960-b1_45.2_0012.jp2'],
}

input_folder='/dor/preassembly/remediation/revs_jp2'

puts "#{druids.size} objects to work on, source folder: #{input_folder}"
druids.each do |druid,files|

  puts "Working on #{druid}"

  i=Dor::Item.find(druid)
  i.publish_metadata # republish metadata
  puts "...republished metadata"

  workspace_druid = DruidTools::Druid.new(druid,Dor::Config.stacks.local_workspace_root) # get the workspace folder
  workspace_druid.content_dir # create the workspace content folder if it does not exist
  files.each do |file|
   src=File.join(input_folder,file)
   dest=File.join(workspace_druid.content_dir,file)
   FileUtils.cp src,dest # copy files from our source to the workspace
   puts "...copied #{file} to #{dest}"
  end
  Dor::DigitalStacksService.shelve_to_stacks(druid,files) # shelve em!
  puts "...shelved"

  puts ""

end