# Given the full path to a folder containing manifest files, it will offer to create a pre-assembly YAML file
# This requires you to (1) already have CSV manifest files in the same folder as the content, (2) enter the collection druid for the each manifest.
# It will iterate over the input folder, find all CSVs, and offer to create a YAML file at the folder level above.

# Peter Mangiafico
# April 10, 2015
#
# Run with
#  ROBOT_ENVIRONMENT=production ruby devel/revs_create_yaml.rb /dor/staging/Revs
STDOUT.sync = true

ARCHIVE_DRUIDS={:revs=>'druid:nt028fd5773',:roadandtrack=>'druid:mr163sv5231'}  # a hash of druids of the master archives, keys are arbitrary but druids must match the druids in DOR

yaml_template = '/dor/staging/Revs/revs_template_preassembly_yaml_file.yaml' # the template file to copy from

require 'yaml'
require File.expand_path(File.dirname(__FILE__) + '/../config/boot')

raise "Incorrect N of arguments." if ARGV.size != 1
input = ARGV[0]

puts "revs_create_yaml"
puts "Input: #{input}"
puts "YAML Template: #{yaml_template}"

raise "YAML template could not be found or read!" unless File.readable?(yaml_template)

config = YAML.load_file(yaml_template)
base_tag = config['apply_tag']
collection_druids_from_yaml=config['set_druid_id']
if collection_druids_from_yaml.size != 2 || !ARCHIVE_DRUIDS.has_value?(collection_druids_from_yaml[1]) 
  raise "The YAML template file has an issue with the set_druid_id params; there must be two entries, the first will be replaced by this script, the second must be the master Archive collection (e.g. Revs/R&T)"
end

puts ''

counter = 0
    
if File.directory?(input)

  puts "Searching for CSV files..."
  FileUtils.cd(input)
  files=Dir.glob("**/**.csv") + Dir.glob("**/**.CSV")
  num_files=files.count
  puts "Found #{num_files} CSV files"
  puts ""
  puts "For each manifest, enter in the druid (with druid: prefix) of the collection that this YAML file relates to."
  puts "You can press return (blank) to skip the manifest." 
  files.each do |file|

    puts ""
    print "#{file} - enter collection druid: "
    collection_druid=STDIN.gets.chomp 

    unless collection_druid.blank?
        begin
          DruidTools::Druid.new(collection_druid)
          name_without_extension=File.basename(file,File.extname(file))
          output_file=File.join(input,File.dirname(file),"..",name_without_extension+".yaml") # go one level up from CSV file
          puts "Writing #{output_file}"
          config['set_druid_id'][0] = collection_druid # set collection druid
          config['bundle_dir']=File.join(input,File.dirname(file))
          config['manifest']=File.basename(file)
          config['apply_tag']=base_tag + name_without_extension.gsub(' ','_') # append a tag with the name of the manifest, but with no spaces
          config['progress_log_file']=File.join('/dor/preassembly/revs/',name_without_extension+".log")
          File.open(output_file,'w') do |h|
            h.write config.to_yaml
          end
          counter+=1
        rescue
          puts "Invalid collection druid entered, skipping #{file}"
        end
    else
       puts "No collection druid entered, skipping #{file}"
    end

  end 
  
  puts ""
  puts "completed #{num_files}, created YAML files for #{counter}"
  
else

  puts "ERROR: Input '#{input}' is not a directory"
  
end

puts ''