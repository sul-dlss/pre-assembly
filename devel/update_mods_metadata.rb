# Used to update descriptive Metadata from updated CSV.
# Iterate through each row in the CSV, generate new MODs using provided MODs template, update each object using remediation framework.

# You need to provide a CSV with either druids or sourceid in a column labeled as "druid" or "sourceid".
#  The CSV should also include all other columns necessary for the MODs template.
#  You also need to provide the MODs template.

# Both the CSV and the MODs template should on lyberservices-prod in an accessible location that is writable (e.g. /dor/preassembly/remediation)

# Peter Mangiafico
# December 6, 2015
#
# Run with

# RAILS_ENV=production ruby devel/update_mods_metadata.rb [full_path_to_manifest_csv] [full_path_to_mods_template]

# e.g.
# RAILS_ENV=production ruby devel/update_mods_metadata.rb /dor/preassembly/remediation/manifest_phillips_1954-test.csv /dor/staging/revs/mods_template.xml

# this will only run on lyberservices-prod since it needs access to the MODs template and mods remediation file
$stdout.sync = true

help "Incorrect N of arguments." if ARGV.size != 2
csv_in = ARGV[0]
mods_template_file = ARGV[1]

abort "CSV file not found." unless File.file? csv_in
abort "MODs template not found." unless File.file? mods_template_file

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')
require 'csv'

remediate_logic_file = '/dor/preassembly/remediation/scripts/update_mods_remediation.rb' # the update mods remeditation class
require remediate_logic_file

source_path = File.dirname(csv_in)
source_name = File.basename(csv_in, File.extname(csv_in))
progress_log_file = File.join(source_path, source_name + '_log.yml')
csv_out = File.join(source_path, source_name + "_log.csv")

# read in completed druids so we don't reprocess them
completed_druids = PreAssembly::Remediation::Item.get_druids(progress_log_file)

# read in MODs template
mods_template_xml = IO.read(mods_template_file)

# read input manifest
file_contents = IO.read(csv_in).encode("utf-8", replace: nil)
csv = CSV.parse(file_contents, :headers => true)
@items = csv.map { |row| row.to_hash.with_indifferent_access }
num_rows = @items.size
puts "Found #{num_rows} rows"

@items.each_with_index do |manifest_row, x|
  print "#{x + 1} of #{num_rows} : "
  if manifest_row[:sourceid] # we have a sourceid column, look up the druid
    pids = Dor::SearchService.query_by_id("#{manifest_row[:sourceid].strip}")
    if pids.size != 1
      puts "cannot find single pid for source id '#{manifest_row[:sourceid]}'"
      next
    else # found a single druid
      pid = pids.first
    end # end check for found a druid
  elsif manifest_row[:druid] # we have a druid column
    pid = manifest_row[:druid].strip
    pid = "druid:#{pid}" unless pid.include?("druid:") # add the druid prefix if missing
  else
    puts "abort: cannot find druid or sourceid column in manifest"
    break
  end # end check for we have sourceid/druid column
  done = completed_druids.include?(pid)
  if done
    puts "#{pid} : skipping, already completed"
  else
    # create data structure we will pass into remediation code
    data = { :desc_md_template_xml => mods_template_xml, :manifest_row => manifest_row }
    item = PreAssembly::Remediation::Item.new(pid, data)
    item.description = "Updating metadata from #{csv_in}" # added to the version description
    item.extend(RemediationLogic) # add in our project specific methods
    success = item.remediate
    item.log_to_progress_file(progress_log_file)
    item.log_to_csv(csv_out)
    puts "#{pid} : #{success}"
  end # end check for already done
end # end loop over all rows
