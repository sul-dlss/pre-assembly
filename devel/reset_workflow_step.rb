# run with ruby devel/add_and_update_files.rb
# must be run from lyberservices-prod to have access to all mounts and configuration

#!/usr/bin/env ruby
ENV['ROBOT_ENVIRONMENT']='production'  # environment to run under (i.e. which fedora instance to hit)

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')

require 'rubygems'
require 'dor-services'
require 'assembly-utils'
require 'logger'
require 'net/ssh'

dry_run=false # if set to true, then no operations are actually carried out, you only get notices of what will happen
log_file='/dor/preassembly/revs/revs_ludvigsen-1971_log.yaml'
workflow='accessionWF'
step='rights-metadata'
state='waiting'

completed_druids=Assembly::Utils.get_druids_from_log(log_file,true)
puts "found #{completed_druids.size} druids"
completed_druids.each_with_index do |druid,index|
  desc_filename=File.join(DruidTools::Druid.new(druid,'/dor/assembly').path(),'metadata','descMetadata.xml')
  puts "#{druid} [#{index+1} of #{completed_druids.size}]: reseting #{workflow}:#{step} to #{state}"
  Dor::WorkflowService.update_workflow_status('dor',druid,workflow, step, state) unless dry_run
end