# Given the full path to a manifest file or a folder containing manifest files, confirm it has all of the correct headers and no extras.  Useful to run before Revs accessioning.

# Peter Mangiafico
# June 18, 2014
#
# Run with
# ROBOT_ENVIRONMENT=production ruby devel/revs_check_manifest.rb /dor/preassembly/remediation/manifest_phillips_1954-test.csv

help "Incorrect N of arguments." if ARGV.size != 1
input = ARGV[0]

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')
require 'revs-utils'

class RevsUtils
  extend Revs::Utils    
end

def check_file(file)
  reg=RevsUtils.valid_to_register(file)
  source=RevsUtils.unique_source_ids([file])
  metadata=RevsUtils.valid_for_metadata(file)
  puts "#{file},#{reg},#{source},#{metadata}"
  return reg && source && metadata
end

puts ''

puts "File,Registration Columns OK,Source IDs/Filenames OK & Unique,Metadata Columns OK"

if File.file?(input) && File.extname(input).downcase == '.csv'
  
  check_file(input)
  
elsif File.directory?(input)

  num_errors=0
  FileUtils.cd(input)
  files=Dir.glob("**/**.csv")
  files.each do |file|
     ok=check_file(file)
     num_errors +=1 unless ok
  end 
  puts "#{num_errors} files had problems"
  
else

  puts "ERROR: Input '#{input}' is not a CSV file or directory"
  
end

puts ''