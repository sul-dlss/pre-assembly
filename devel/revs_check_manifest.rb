# Given the full path to a manifest file or a folder containing manifest files, confirm it has all of the correct headers and no extras.  Useful to run before Revs accessioning.

# Peter Mangiafico
# June 18, 2014
#
# Run with
#  ROBOT_ENVIRONMENT=production ruby devel/revs_check_manifest.rb /dor/preassembly/remediation/manifest_phillips_1954-test.csv

help "Incorrect N of arguments." if ARGV.size != 1
input = ARGV[0]

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')

puts ''

puts "File, Registration Columns OK , Metadata Columns OK, Num Bad Formats or Dates "
counter = 0

if File.file?(input) && File.extname(input).downcase == '.csv'

#  puts "Working on #{input}"
  csv_data = RevsUtils.read_csv_with_headers(input)
  reg=RevsUtils.check_valid_to_register(csv_data) # check for valid registration
  headers=RevsUtils.check_headers(csv_data) # check for valid metadata columns
  metadata=RevsUtils.check_metadata(csv_data) # check for certain valid metadata values
  puts "#{input} , #{reg} , #{headers}, #{metadata}"

elsif File.directory?(input)

  puts "Searching for CSV files..."
  num_errors=0
  FileUtils.cd(input)
  files=Dir.glob("**/**.csv")
  num_files=files.count
  puts "Found #{num_files} CSV files"
  files.each do |file|
    counter += 1
#    puts "Working on #{file}: (#{counter} of #{num_files})"
    csv_data = RevsUtils.read_csv_with_headers(file)
    reg=RevsUtils.check_valid_to_register(csv_data) # check for valid registration
    headers=RevsUtils.check_headers(csv_data) # check for valid metadata columns
    metadata=RevsUtils.check_metadata(csv_data) # check for certain valid metadata values
    puts "#{file} , #{reg} , #{headers}, #{metadata}"
    ok = (reg && headers && (metadata == 0))
    num_errors +=1 unless ok
  end
  puts "#{num_errors} files out of #{num_files} had problems"

else

  puts "ERROR: Input '#{input}' is not a CSV file or directory"

end

puts ''