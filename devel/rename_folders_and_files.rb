# Pass in input base folder and CSV file with two columns (sourceid,druid)
# Script will iterate over base folder and rename any folders it finds called sourceid to druid
# It will then go into the newly renamed folder and find any files/subfolders that contain sourceid and rename them to druid

# call this with
# ruby devel/rename_folders_and_files.rb BASE_FOLDER CSV_FILE

require 'rubygems'
require 'bundler/setup'

require 'csv'
require 'csv-mapper'
require 'fileutils'

@base_folder = ARGV[0]
@csv_filename = ARGV[1]

@items = CsvMapper.import(@csv_filename) do read_attributes_from_file end

@items.each do |row|
  sourceid = row.sourceid
  druid = row.druid
  puts "Working on #{sourceid} -- renaming to #{druid}"

  # rename entire folder
  FileUtils.mv File.join(@base_folder, sourceid), File.join(@base_folder, druid)

  # go into renamed folder
  FileUtils.cd(File.join(@base_folder, druid))

  Dir.glob("**/*").each do |file|
    if file.include?(sourceid)
      old_name = File.join(@base_folder, druid, file)
      new_name = File.join(@base_folder, druid, file.gsub(sourceid, druid))
      puts "...renaming #{old_name} to #{new_name}"
      FileUtils.mv old_name, new_name
    end
  end
end
