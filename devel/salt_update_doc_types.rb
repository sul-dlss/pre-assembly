# Used to update descriptive Metadata from updated manifests for the Salt Project
# Iterate through each row in the manifest, use the supplied druid, update the descMetadata as needed using
# remediation framework.

# Peter Mangiafico
# February 3, 2016
#
# Run with
# ROBOT_ENVIRONMENT=production nohup ruby devel/salt_update_doc_types.rb /dor/preassembly/remediation/salt/feigenbaum_updated_doc_types_final.csv > feigenbaum_update_doc_types.out 2>&1&

# this will only run on lyberservices-prod since it needs access to the remediation file

help "Incorrect N of arguments." if ARGV.size != 1
csv_in = ARGV[0]

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')
require 'csv'
require 'csv-mapper'
include CsvMapper

remediate_logic_file = '/dor/preassembly/remediation/scripts/update_salt_document_types_remediation.rb' # the salt update mods remeditation class
require remediate_logic_file

source_path = File.dirname(csv_in)
source_name = File.basename(csv_in, File.extname(csv_in))
progress_log_file = File.join(source_path, source_name + '_log.yml')
csv_out = File.join(source_path, source_name + "_log.csv")

# read in completed druids so we don't reprocess them
completed_druids = PreAssembly::Remediation::Item.get_druids(progress_log_file)

# read input manifest
@items = CsvMapper.import(csv_in) do read_attributes_from_file end

@items.each_with_index do |row, _x|
  manifest_row = Hash[row.each_pair.to_a]
  pid = manifest_row[:druid]
  done = completed_druids.include?(pid)
  if done
    puts "#{pid} : skipping, already completed"
  else
    # create data structure we will pass into remediation code
    data = { :manifest_row => manifest_row }
    item = PreAssembly::Remediation::Item.new(pid, data)
    item.description = "Updating document types from #{csv_in}" # added to the version description
    item.extend(RemediationLogic) # add in our project specific methods
    success = item.remediate
    item.log_to_progress_file(progress_log_file)
    item.log_to_csv(csv_out)
    puts "#{pid} : #{success}"
  end
end
