# Pass in input base folder and CSV file with two columns (sourceid,druid)
# Script will iterate over base folder and rename any files it finds that contain sourceid, replacing it with druid
# It will do this iteratively over all files contained in the source directory, but will ignore folders

# call this with
# ruby devel/rename_files.rb BASE_FOLDER CSV_FILE

require 'rubygems'
require 'bundler/setup'

require 'csv'
require 'csv-mapper'
require 'fileutils'

@base_folder = ARGV[0]
@csv_filename = ARGV[1]

@items = CsvMapper.import(@csv_filename) do read_attributes_from_file end

# go into base folder
FileUtils.cd(@base_folder)

# grab all files recurisvely in source folder
files = Dir.glob("**/**")

@items.each do |row|
  sourceid = row.sourceid
  druid = row.druid
  puts "Working on '#{sourceid}' -- renaming all files with this value to '#{druid}'"

  files.each do |file|
    orig_file = File.join(@base_folder, file)
    dir = File.dirname(orig_file)
    filename = File.basename(orig_file)
    if File.file?(orig_file) && filename.include?(sourceid) # only operate on files, and only update filenames, not folder names
      new_file = File.join(dir, filename.gsub(sourceid, druid))
      puts "...renaming #{orig_file} to #{new_file}"
      FileUtils.mv orig_file, new_file
    end
  end
end
