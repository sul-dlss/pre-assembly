# run with ruby devel/performance_test.rb

#!/usr/bin/env ruby
ENV['ROBOT_ENVIRONMENT']='test'  # environment to run under (i.e. which fedora instance to hit)

ENABLE_SOLR_UPDATES = false

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')

require 'rubygems'
require 'dor-services'

test_druids=%w{druid:bb060mk7924 druid:bb101mm5282 druid:bb298yx8728 druid:bb446hg7927 druid:bb456wp8129}
number_of_loops=1
run_publish_step = false # only works when running on a server

i=0
load_times=0
save_times=0
pub_times=0
parse_times=0

num_objects=number_of_loops*test_druids.size

start_time=Time.now
puts "Starting run at #{start_time}"
puts "Running #{test_druids.size} druids over #{number_of_loops} loops for a total of #{num_objects} object updates"
puts ""

while i < number_of_loops do
  puts "*** on loop #{i+1}"
  test_druids.each do |druid|
    puts "****** running #{druid}"
    load_time_start=Time.now
    obj=Dor::Item.find(druid)
    load_times+=Time.now-load_time_start

    parse_time_start=Time.now
    descMD=Nokogiri::XML(obj.descMetadata.content)
    current_title=descMD.search('title').first.content
    new_title="#{current_title} - #{Time.now}"
    descMD.search('title').first.content=new_title
    obj.descMetadata.content=descMD.to_xml
    parse_times+=Time.now-parse_time_start
    
    save_time_start=Time.now
    obj.save
    save_times+=Time.now-save_time_start

    if run_publish_step
      pub_time_start=Time.now
      obj.publish_metadata
      pub_times+=Time.now-pub_time_start
    end
    
    obj = nil
  end
  i += 1
end

end_time=Time.now
puts ""
puts "Run finished at #{end_time}"
puts "Total time for #{num_objects}: #{(end_time-start_time).round(2)} seconds"
puts "Average time per object: #{((end_time-start_time)/num_objects).round(2)} seconds/per object"
puts "Load time total: #{load_times.round(2)} seconds"
puts "Parse time total: #{parse_times.round(2)} seconds"
puts "Save time total: #{save_times.round(2)} seconds"
puts "Pub time total: #{pub_times.round(2)} seconds" if run_publish_step


