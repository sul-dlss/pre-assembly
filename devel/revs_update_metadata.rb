# Used to update descriptive Metadata from updated manifests provided by Revs Institute.
# Iterate through each image, use source ID to lookup DRUID, generate new MODs using MODs template, update each object using
# remediation framework.

# Peter Mangiafico
# June 14, 2013
#
# Run with
# ROBOT_ENVIRONMENT=test ruby devel/revs_update_metadata.rb /dor/preassembly/remediation/manifest_phillips_1954-test.csv

# this will only run on lyberservices-prod since it needs access to the MODs template and mods remediation file

help "Incorrect N of arguments." if ARGV.size != 1
csv_in = ARGV[0]

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')
require 'csv'
require 'csv-mapper'
include CsvMapper

remediate_logic_file='/thumpers/dpgthumper-staging/Revs/revs_update_mods_remediation.rb' # the revs update mods remeditation class
mods_template_file='/thumpers/dpgthumper-staging/Revs/mods_template.xml' # the revs MODs template
require remediate_logic_file

source_path=File.dirname(csv_in)
source_name=File.basename(csv_in,File.extname(csv_in))
progress_log_file=File.join(source_path,source_name + '_log.yml')
csv_out=File.join(source_path, source_name + "_log.csv")

# read in completed druids so we don't reprocess them
completed_druids=PreAssembly::Remediation::Item.get_druids(progress_log_file)

# read in MODs template
mods_template_xml=IO.read(mods_template_file)


# read input manifest
@items=CsvMapper.import(csv_in) do read_attributes_from_file end
  
@items.each_with_index do |row, x|
  manifest_row  = Hash[row.each_pair.to_a]
  pid=Dor.find_by_sourceid("Revs:#{manifest_row[:sourceid]}") # grab the PID given the sourceID
#  pid='druid:qh202yd6550'  
  done=completed_druids.include?(pid)
   if done 
     puts "#{pid} : skipping, already completed"
   else
     # create data structure we will pass into remediation code
     data={:desc_md_template_xml=>mods_template_xml,:manifest_row=>manifest_row}
     item=PreAssembly::Remediation::Item.new(pid,data)
     item.description="Updating metadata from #{csv_in}" # added to the version description
     item.extend(RemediationLogic) # add in our project specific methods
     success=item.remediate
     item.log_to_progress_file(progress_log_file)
     item.log_to_csv(csv_out)
     puts "#{pid} : #{success}"    
   end
   
end