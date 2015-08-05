# starting with a CSV file of druids, check to see if the druid is fully accessioned and ingested, and not currently in accessioning
# and if so, cleanup from /dor/workspace and /dor/assembly folders
# csv file needs a header of of at least "Druid", one druid per row
# ruby devel/dor_workspace_cleanup.rb druids.csv

ENV['ROBOT_ENVIRONMENT']='production'  # environment to run under (i.e. which fedora instance to hit)

paths_to_cleanup=['/dor/assembly','/dor/workspace']

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')

abort "Incorrect N of arguments." unless ARGV.size == 1
csv_in = ARGV[0]   

# read input manifest
csv_data = RevsUtils.read_csv_with_headers(csv_in) 
total=csv_data.size

start_time=Time.now
puts ""

n=0
fixed=0
not_fixed=0
not_available=0

puts "Read data from #{csv_in}"
puts "Found #{total} druids"
puts "Cleaning up /dor/assembly and /dor/workspace"
puts "Started at #{start_time}"

csv_data.each do |row|

  n+=1

  pid=row['Druid']
  druid=(pid.include?("druid:") ? pid : "druid:#{pid}")
  
  unless pid.blank?
    
    msg="#{n} of #{total}: #{druid}"
    deleted_from=[]
    if Assembly::Utils.updates_allowed?(druid)
      paths_to_cleanup.each do |root_dir|
        folder=DruidTools::Druid.new(druid,root_dir).path()
        if Dir.exists?(folder)
          FileUtils.rm_r(folder)
          deleted_from << root_dir
        end
      end 
      if deleted_from.size > 0
        puts "#{msg}: deleted folders from #{deleted_from.join(', ')}"
        fixed+=1
      else
        not_fixed+=1
        puts "#{msg}: no folders required to be deleted"
      end
    else
      puts "#{msg}: no action taken - currently in accessioning and cannot be updated"
      not_available+=1
    end    
  
  end
  
end

puts ""
puts "#{fixed} had folders deleted, #{not_fixed} had no action needed, #{not_available} were currently in accessioning or unavailable for removal"
puts "Completed at #{Time.now}, total time was #{'%.2f' % ((Time.now - start_time)/60.0)} minutes"