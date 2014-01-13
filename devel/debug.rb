require File.expand_path(File.dirname(__FILE__) + '/../config/boot')
require 'csv'
require 'csv-mapper'
include CsvMapper

csv_in='/dor/staging/Revs/Ludvigsen/LUDV_1968/manifest_ludvigsen_partial.csv'
remediate_logic_file='/thumpers/dpgthumper-staging/Revs/revs_update_mods_remediation.rb' # the revs update mods remeditation class
mods_template_file='/thumpers/dpgthumper-staging/Revs/mods_template.xml' # the revs MODs template
require remediate_logic_file

source_path=File.dirname(csv_in)
source_name=File.basename(csv_in,File.extname(csv_in))
progress_log_file=File.join(source_path,source_name + '_log.yml')
csv_out=File.join(source_path, source_name + "_log.csv")

# read in completed druids so we don't reprocess them
#completed_druids=PreAssembly::Remediation::Item.get_druids(progress_log_file)

# read in MODs template
mods_template_xml=IO.read(mods_template_file)

# read input manifest
@items=CsvMapper.import(csv_in) do read_attributes_from_file end

manifest_row  = Hash[@items[0].each_pair.to_a]
pids=Dor::SearchService.query_by_id("Revs:#{manifest_row[:sourceid]}")
if pids.size != 1
  puts "cannot find single pid for source id #{row.sourceid}"
else
  pid=pids.first  
  # done=completed_druids.include?(pid)
  #  if done 
  #    puts "#{pid} : skipping, already completed"
  #  else
     # create data structure we will pass into remediation code
     data={:desc_md_template_xml=>mods_template_xml,:manifest_row=>manifest_row}
     item=PreAssembly::Remediation::Item.new(pid,data)
     item.description="Updating metadata from #{csv_in}" # added to the version description
     item.extend(RemediationLogic) # add in our project specific methods
     success=item.remediate
     item.log_to_progress_file(progress_log_file)
     item.log_to_csv(csv_out)
     puts "#{pid} : #{success}"    
   # end
end