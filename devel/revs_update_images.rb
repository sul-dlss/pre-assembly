# Used to update images from an update set of image files and a small manifest containing sourceIDs
# Iterate through each image in the manifest, use source ID to lookup DRUID, add the new image to the object, re-shelve it, and then
# update contentMetadata using the remediation framework.  Since we are not re-generating descMetadata, the only required columns in
# the manifest are 'sourceid' and 'filename' (include the header row with these columns)

# Peter Mangiafico
# June 17, 2013
#
# Run with
# ROBOT_ENVIRONMENT=test ruby devel/revs_update_images.rb /dor/preassembly/remediation/manifest_phillips_1954-test.csv

# this will only run on lyberservices-prod since it needs access to the image remediation file

help "Incorrect N of arguments." if ARGV.size != 1
csv_in = ARGV[0]

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')
require 'csv'
require 'csv-mapper'
include CsvMapper

remediate_logic_file='/dor/preassembly/remediation/scripts/revs_update_images_remediation.rb' # the revs update mods remeditation class
require remediate_logic_file

source_path=File.dirname(csv_in)
source_name=File.basename(csv_in,File.extname(csv_in))
progress_log_file=File.join(source_path,source_name + '_log.yml')
csv_out=File.join(source_path, source_name + "_log.csv")

# read in completed druids so we don't reprocess them
completed_druids=PreAssembly::Remediation::Item.get_druids(progress_log_file)

# read input manifest
@items=CsvMapper.import(csv_in) do read_attributes_from_file end
  
@items.each_with_index do |row, x|
  pids=Dor::SearchService.query_by_id("Revs:#{row.sourceid}")
  if pids.size != 1
    puts "cannot find single pid for source id #{row.sourceid}"
  else
    pid=pids.first
    done=completed_druids.include?(pid)
     if done 
       puts "#{pid} : skipping, already completed"
     else
       data={:source_path=>source_path,:filename=>row.filename}
       item=PreAssembly::Remediation::Item.new(pid,data)
       item.description="Updating image from #{csv_in}" # added to the version description
       item.extend(RemediationLogic) # add in our project specific methods
       success=item.remediate
       item.log_to_progress_file(progress_log_file)
       item.log_to_csv(csv_out)
       puts "#{pid} : #{success}"    
     end
   end
   
end