# Pass in input base folder and CSV file with two columns (sourceid,druid)
# Script will iterate over base folder and rename any items it finds that contain sourceid, replacing it with druid
# It will do this iteratively over all files and folders contained in the source directory
# NOTE - if the input base folder contains sub-folders, and those sub-folders contain instances of sourceid, you will run into issues

# call this with 
# ruby devel/rename_files BASE_FOLDER CSV_FILE

require 'rubygems'
require 'bundler/setup'

require 'csv'
require 'csv-mapper'
require 'fileutils'


@base_folder=ARGV[0]
@csv_filename=ARGV[1]

@items=CsvMapper.import(@csv_filename) do read_attributes_from_file end  

# go into base folder
FileUtils.cd(@base_folder)

# grab all files and folders
files=Dir.glob("**/**")

@items.each do |row|
  sourceid=row.sourceid
  druid=row.druid
  puts "Working on #{sourceid} -- renaming to #{druid}"
  
  files.each do |file|
    old_name=File.join(@base_folder,file)
    if File.file?(old_name) && file.include?(sourceid)
      new_name=File.join(@base_folder,file.gsub(sourceid,druid))
      puts "...renaming #{old_name} to #{new_name}"
      FileUtils.mv old_name,new_name
    end
  end

end

