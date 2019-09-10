#! /usr/bin/env ruby
require File.expand_path(File.dirname(__FILE__) + '/../config/boot')

require 'csv'
require 'druid-tools'

# Copies files from the stacks into a separate folder given a list of druids
# Pass into the full path to the input CSV below and the full path to the output location.
# The input CSV must have a column called 'druid' containing the druid, other columns are ignored
# August 29, 2019
# Written by: Peter Mangiafico
# To produce data requested by: Nicole Coleman
# Project use:
#  1. Exporting ETDs for export to EBSCO (use unknown)
#  2. Exporting ETD PDFs and MODs files for Yewno (will be used to see if Yewno can extract keywords for potential metadata supplementing)

# run with:
# ROBOT_ENVIRONMENT=production ruby devel/grab_files_from_stacks FULL_PATH_TO_INPUT.csv FULL_PATH_TO_OUTPUT_FOLDER
# e.g. ROBOT_ENVIRONMENT=production ruby devel/grab_files_from_stacks '/dor/staging/Yewno/WorldViewETDs.csv' '/dor/staging/Yewno'

input_file = ARGV[0]
output_location = ARGV[1]

raise "input file #{input_file} not found!" unless File.exist?(input_file)
raise "output folder location #{output_location} not found!" unless File.directory?(output_location)

csv_text = File.read(input_file)
results = CSV.parse(csv_text, headers: true)

puts "Input file: #{input_file}"
puts "Output location: #{output_location}"
num_rows = results.size
puts "Found #{num_rows} rows"

results.each_with_index do |row, i|
   pid = row['druid'] || row['Druid'] || row['DRUID']
   druid = pid.include?('druid') ? pid : "druid:#{pid}" # add druid prefix if needed
   puts "[#{i+1} of #{num_rows}] : #{druid}"
   dt = DruidTools::Druid.new(druid)
   bare_druid = dt.id
   path_to_stacks = "/stacks/#{dt.path.gsub(bare_druid,'')}"
   path_to_purl_cache = "/purl/document_cache/#{dt.path.gsub(bare_druid,'')}"

   # copy all files from the stacks
   FileUtils.cd(path_to_stacks)
   existing_files = Dir.glob('*.*')
   output_druid_location = File.join(output_location,bare_druid)
   FileUtils.mkdir_p output_druid_location
   existing_files.each do |filename|
     FileUtils.cp File.join(path_to_stacks, filename), output_druid_location
   end

   # copy mods from the purl cache
   FileUtils.cd(path_to_purl_cache)
   FileUtils.cp File.join(path_to_purl_cache, 'mods'), output_druid_location
end
