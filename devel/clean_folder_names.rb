# Pass in input base folder
# Script will iterate over top level folders, renaming to remove spaces and special characters

# call this with
# ruby devel/clean_folder_names.rb BASE_FOLDER

require 'rubygems'
require 'bundler/setup'

require 'fileutils'

input=ARGV[0]

# go into base folder
FileUtils.cd(input)

# grab all folders
folders=Dir.glob('*').select {|f| File.directory? f}
excluded=['System Volume Information','$RECYCLE.BIN']
folders.reject! {|folder| excluded.include?(folder)}

puts "Found #{folders.size} folders"
renamed=0
folders.each do |folder|
  clean_name = folder.gsub(/[^a-zA-Z0-9\-\_]/,"").strip
  if folder != clean_name
    puts "...renaming '#{folder}' to '#{clean_name}'"
    renamed+=1
    FileUtils.mv File.join(input,folder),File.join(input,clean_name)
  end
end
puts "Renamed #{renamed} folders"
