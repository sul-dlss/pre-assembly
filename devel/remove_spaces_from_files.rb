# Pass in input base folder 
# Script will iterate over base folder and remove any spaces it finds in filenames
# It will do this iteratively over all files contained in the source directory, but will ignore folders

# call this with 
# ruby devel/remove_spaces_from_files.rb BASE_FOLDER

require 'rubygems'
require 'bundler/setup'

require 'fileutils'

@base_folder=ARGV[0]

# go into base folder
FileUtils.cd(@base_folder)

# grab all files recurisvely in source folder
files=Dir.glob("**/**")

puts "Found #{files.size} files"
renamed=0
files.each do |file|
  orig_file=File.join(@base_folder,file)
  dir=File.dirname(orig_file)
  filename=File.basename(orig_file)
  if File.file?(orig_file) && !filename.match(/\s/).nil? # only operate on files, and only update filenames, not folder names
    new_file=File.join(dir,filename.gsub(' ',''))
    puts "...renaming #{orig_file} to #{new_file}"
    renamed+=1
    FileUtils.mv orig_file,new_file
  end
end
puts "Renamed #{renamed} files"
