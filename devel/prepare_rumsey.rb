# Used to stage content from Rumsey format to folder structure ready for accessioning.
# Iterate through each row in the manifest, find files, generate contentMetadata and copy to new location.

# Peter Mangiafico
# May 6, 2015
#
# Run with
# ROBOT_ENVIRONMENT=production ruby devel/prepare_rumsey.rb /maps/ThirdParty/Rumsey/Rumsey_Batch1.csv

# this will only run on lyberservices-prod since it needs access to the MODs template and mods remediation file
#  input CSV should have columns labeled "Object", "Image", and "Label" -- 
#   image is the filename, object is the object identifier (turned into a folder)

help "Incorrect N of arguments." if ARGV.size != 1
csv_in = ARGV[0]

dry_run=false # will only show output, won't actually copy files or create anything, switch to false to actually run

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')
require 'revs-utils'

class RevsUtils
  extend Revs::Utils    
end

base_content_folder='/maps/ThirdParty/Rumsey/content/content_2015-02-12' # base folder to search for content
staging_folder='/maps/ThirdParty/Rumsey/staging' # location to stage content to

source_path=File.dirname(csv_in)
source_name=File.basename(csv_in,File.extname(csv_in))
csv_out=File.join(source_path, source_name + "_log.csv")

unless File.exists?(csv_out) # if we don't already have a log file, write out the header row
  CSV.open(csv_out, 'a') {|f| 
    output_row=["Object","Filename","Success","Message","Time"]
    f << output_row
  }  
end

# read in existing log file
log_file_data=RevsUtils.read_csv_with_headers(csv_out)

# read input manifest
csv_data = RevsUtils.read_csv_with_headers(csv_in) 

start_time=Time.now
puts ""
puts "Rumsey Prepare"
puts "WARNING: DRY RUN!" if dry_run
puts "Input CSV File: #{csv_in}"
puts "Logging to: #{csv_out}"
puts "Base Content Folder: #{base_content_folder}"
puts "Staging Folder: #{staging_folder}"
puts "Started at: #{start_time}"
puts ""
$stdout.flush

found_objects=[]
n=0
num_files_not_found=0
num_objects=0
num_files_copied=0

csv_data.each do |row|

  n+=1
  puts "Row #{n} out of #{csv_data.size}"
  $stdout.flush
  
  object=row['Object'].gsub(',','-') # commas are no good in filenames, use a dash instead
  row_filename=row['Image']
  label=row['Label']
  #sequence=row['Sequence']
  filename=File.basename(row_filename,File.extname(row_filename)) # remove any extension from the filename that was provided
  
  if log_file_data.select {|row| row["Filename"] == filename && row["Success"] == "true" }.size == 0 # check to see if we have already successfully run this file
    
    object_folder=File.join(staging_folder,object)

    unless found_objects.include? object # we have a new object
      FileUtils.mkdir_p object_folder unless dry_run
      found_objects << object
      puts "...#{Time.now}: Found new object: '#{object}', creating object folder '#{object_folder}'"
      num_objects+=1
    end

    # now search for file
    puts "......#{Time.now}: looking for file '#{filename}', label '#{label}'"
    files=Dir.glob("#{base_content_folder}/**/#{filename}.*")
  
    # if found, copy first file to staging directory (if it does not exist)
    if files.size > 0
      input_file=files[0]
      message= "found #{input_file}, copying to object folder #{object_folder}"
      output_file=File.join(object_folder,File.basename(files[0]))
      FileUtils.cp input_file, output_file unless (dry_run || File.exists?(output_file))
      num_files_copied+=1
      success=true
    else
      message="ERROR #{filename} NOT FOUND"
      num_files_not_found+=1
      success=false
    end

    CSV.open(csv_out, 'a') {|f| 
      output_row=[object,filename,success,message,Time.now]
      f << output_row
      puts "......#{message}"
      $stdout.flush
    }  
  
    puts ""
  
  else
    
    puts "......#{Time.now}: skipping #{object} - already run"
       
  end # end check to see if we have already successfully run this filename
  
end

puts ""
puts "Total objects staged: #{num_objects}"
puts "Total files copied: #{num_files_copied}"
puts "Total files not found: #{num_files_not_found}"
puts "Completed at #{Time.now}, total time was #{'%.2f' % ((Time.now - start_time)/60.0)} minutes"