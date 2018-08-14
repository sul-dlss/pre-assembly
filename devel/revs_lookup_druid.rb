# Used to lookup druids based on sourceID
# Input is a csv with a column on 'sourceid', output is a csv with 'druid'

# Peter Mangiafico
# September 29, 2015
#
# Run with
# ROBOT_ENVIRONMENT=production ruby devel/revs_lookup_druid.rb /dor/preassembly/remediation/imagecorrections.csv

help "Incorrect N of arguments." if ARGV.size != 1
csv_in = ARGV[0]

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')
require 'csv'
require 'csv-mapper'
include CsvMapper

source_path = File.dirname(csv_in)
source_name = File.basename(csv_in, File.extname(csv_in))
csv_out = File.join(source_path, source_name + "_output.csv")

# read input manifest
@items = CsvMapper.import(csv_in) do read_attributes_from_file end
puts "Found #{@items.size} source ids in #{source_name}"
puts ""

CSV.open(csv_out, "wb") do |csv|
  csv << ['druid', 'sourceid']
  @items.each_with_index do |row, x|
    pids = Dor::SearchService.query_by_id("Revs:#{row.sourceid}")
    if pids.size != 1
      puts "#{x + 1} of #{@items.size}: cannot find single pid for source id #{row.sourceid}"
    else
      pid = pids.first
      puts "#{x + 1} of #{@items.size}: found #{pid} for #{row.sourceid}"
      csv << [pid, row.sourceid]
    end
  end
end

puts ""
puts "Done.  Output file is #{csv_out}"
