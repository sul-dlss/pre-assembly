# publish items with bad desc metadata for Revs

# run with ruby devel/republish_metadata.rb
# must be run from lyberservices-prod to have access to all mounts and configuration

#!/usr/bin/env ruby
ENV['ROBOT_ENVIRONMENT']='production'  # environment to run under (i.e. which fedora instance to hit)

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')

require 'rubygems'
require 'dor-services'
require 'net/ssh'

input_file="/dor/staging/Revs/druids.csv"

rows=CsvMapper.import(input_file){read_attributes_from_file}

puts "#{rows.size} objects to work on"
rows.each do |row|

  druid="druid:#{row['id']}"
  puts "Working on #{druid}"
  i=Dor::Item.find(druid)
  i.publish_metadata # republish metadata
  puts "...republished metadata"

end