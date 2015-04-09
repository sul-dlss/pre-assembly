# Given the full path to a folder containing content and manifest, iterate through, find any XLS or XLSX files, export to CSV, move 
# into folder name with same prefix, and check that manifest is correct.

# Used to prepare CSV manifest from supplied XLS/XLSX from The Revs Institute in preparation for accessioning.

# Peter Mangiafico
# April 5, 2015
#
# Run with
# ROBOT_ENVIRONMENT=production ruby devel/revs_prepare_manifests.rb /Volumes/REVS  # supply folder to iterate over

help "Incorrect N of arguments." if ARGV.size != 1
input = ARGV[0]

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')
require 'revs-utils'
require 'roo'

class RevsUtils
  extend Revs::Utils    
end

if File.directory?(input) 

  puts ""
  puts 'revs_prepare_manifests'
  puts "Started at #{Time.now}"
  puts "Input: #{input}"
  start_time=Time.now

  FileUtils.cd(input)
  files=Dir.glob("**/**.xlsx") + Dir.glob("**/**.xls") # look for all xls and xlsx files
  files.reject! {|file| file.include?("$RECYCLE.BIN")} # ignore stuff in the trash

  num_errors=0
  counter=0
  num_files=files.count

  puts "Found #{num_files} files to process"
  puts ""
  
  puts "Num, File, Saved To, Registration Columns OK , Metadata Columns OK , Num Bad Formats or Dates "

  files.each do |file|
    
    counter += 1 
    base_name = File.basename(file,File.extname(file)) # name of excel file without extension
    filename  = File.basename(file) # name of excel file with extension
    full_path_to_excel = File.join(input,file) # fully qualified path to excel file
    file_directory = full_path_to_excel.gsub(filename,'') # directory that excel file is in
    
    move_to=File.join(file_directory,base_name) # try and find a folder with a matching base name in that same directory
    
    csv_directory = (File.directory?(move_to) ? move_to : file_directory) # if we find it, we will export the CSV there, otherwise just put it in the same place as the Excel file
      
    full_path_to_exported_csv   = File.join(csv_directory,base_name + '.csv') # fully qualified path to the exported CSV file
    
    xlsx = Roo::Spreadsheet.open(full_path_to_excel) # open the excel file
    File.delete(full_path_to_exported_csv) if File.file?(full_path_to_exported_csv) # remove the CSV if it is there
    xlsx.to_csv(full_path_to_exported_csv) # export the CSV file
    
    csv_data = RevsUtils.read_csv_with_headers(full_path_to_exported_csv) 
    reg=RevsUtils.check_valid_to_register(csv_data) # check for valid registration
    headers=RevsUtils.check_headers(csv_data) # check for valid metadata columns
    metadata=RevsUtils.check_metadata(csv_data) # check for certain valid metadata values
        
    ok=(reg && headers && (metadata == 0))

    puts "#{counter}, #{file} , #{move_to} , #{reg} , #{headers}, #{metadata}"
    
    num_errors +=1 unless ok
     
  end 

  puts ""
  puts "#{num_errors} files out of #{num_files} had problems"
  puts "Completed at #{Time.now}, total time was #{Time.now - start_time}"
  
else
  
  puts "Error: #{input} is not a directory"
  
end


puts ''