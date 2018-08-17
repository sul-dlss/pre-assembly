# Used to get a list of druids and filenames given a list of sourceIDs.  Pass in a CSV file with a column of sourceids (labeled as "sourceid").

# Peter Mangiafico
# November 17, 2015
#
# Run with
# ROBOT_ENVIRONMENT=production ruby devel/revs_get_druid_from_sourceid.rb /dor/preassembly/remediation/manifest_phillips_1954-test.csv

# this will only run on lyberservices-prod since it needs access to the image remediation file

help "Incorrect N of arguments." if ARGV.size != 1
csv_in = ARGV[0]

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')
require 'csv'
require 'csv-mapper'
include CsvMapper

source_path = File.dirname(csv_in)

# read input manifest
@items = CsvMapper.import(csv_in) do read_attributes_from_file end

all_pids = []
all_filenames = []

@items.each_with_index do |row, _x|
  pids = Dor::SearchService.query_by_id("Revs:#{row.sourceid}")
  if pids.size != 1
    puts "cannot find single pid for source id #{row.sourceid}"
  else
    all_filenames << "\"#{row.sourceid}.tif\""
    all_pids << "\"#{pids.first}\""
   end
end

puts
puts "filenames = #{all_filenames.join(',')}"
puts
puts "druids = #{all_pids.join(',')}"
puts
