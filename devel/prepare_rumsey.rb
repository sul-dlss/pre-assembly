# Used to stage content from Rumsey format to folder structure ready for accessioning.
# Iterate through each row in the manifest, find files, generate contentMetadata and copy to new location.

# Peter Mangiafico
# June 17, 2015
#
# Run with
# ROBOT_ENVIRONMENT=production ruby devel/prepare_rumsey.rb /maps/ThirdParty/Rumsey/Rumsey_Batch1.csv [--report] [--content-metadata] [--content-metadata-style map]

# this will only run on lyberservices-prod since it needs access to the MODs template and mods remediation file
#  input CSV should have columns labeled "Object", "Image", and "Label"
#   image is the filename, object is the object identifier (turned into a folder)
#
# if you set the --report switch, it will only produce the output report, it will not copy any files
# if you set the --content-metadata switch, it will only generate content metadata for each object using the log file for successfully found files, assuming you also have columns in your input CSV labeled "Druid", "Sequence" and "Label"

# parameters:
base_content_folder='/maps/ThirdParty/Rumsey/content/content_2015-02-12' # base folder to search for content
staging_folder='/maps/ThirdParty/Rumsey/staging' # location to stage content to
# base_content_folder='/Users/petucket/Downloads' # base folder to search for content
# staging_folder='/Users/petucket/Downloads/staging' # location to stage content to

content_metadata_filename='contentMetadata.xml'

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')
require 'optparse'

report=false # if set to true, will only show output and produce report, won't actually copy files or create anything, can be overriden with --report switch
content_metadata=false # if set to true, will also generate content-metadata from values supplied in spreadsheet, can be set via switch
cm_style='map' # defaults to map type content metaadata unless overriden

OptionParser.new do |opts|
  opts.banner = "Usage:\n    ruby prepare_rumsey.rb INPUT_CSV_FILE [--report] [--content_metadata] [--content_metadata_style STYLE]\n"
  opts.on("--report") do |dr|
    report=true
  end
  opts.on("--content_metadata") do |cm|
    content_metadata=true
  end
  opts.on("--content_metadata_style [STYLE]") do |st|
    cm_style=st
  end
end.parse!

abort "Incorrect N of arguments." unless ARGV.size == 1
csv_in = ARGV[0]    

source_path=File.dirname(csv_in)
source_name=File.basename(csv_in,File.extname(csv_in))
csv_out=File.join(source_path, source_name + "_log.csv")

unless File.exists?(csv_out) # if we don't already have a log file, write out the header row
  CSV.open(csv_out, 'a') {|f| 
    output_row=["Object","Image","Filename","Sequence","Label","Druid","Success","Message","Time"]
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
puts "Only producting report" if report
puts "Producing content metadata with style '#{cm_style}'" if content_metadata
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

# only running content_metadata
if content_metadata # create the content metadata 

  log_file_data.each do |row| # loop over log file data
    
    object=row['Object'].gsub(',','-') # commas are no good in filenames, use a dash instead
    druid=row['Druid']

    unless druid # if we don't have a druid in the output log file, look in the input spreadsheet for this object
      input_csv_druids=csv_data.select {|s| s['Object'] == object} # read the druid from the input spreadsheet in case you want to add it later
      input_csv_druids.uniq! {|e| e['Druid']} # remove any duped entries      
      druid=input_csv_druids.first['Druid']
    end
    
    all_files=log_file_data.select {|s| s['Object'] == object && s['Success'] == "true"} # find all files in this object that successfully staged
    
    all_files.uniq! {|e| e['Filename']} # remove any duped filenames (for example, if the log file has multiple entries from multiple runs)
    all_files.sort_by! {|e| e['Sequence'].to_i} # sort the list of files by sequence

    if druid and all_files.size > 0 # be sure we have a druid and files

      object_folder=File.join(staging_folder,object)
    
      cm_file=File.join(object_folder,content_metadata_filename)
  
      content_object_files=[] # build list of assembly objectfiles for creating content metadata
      all_files.each {|object_file| content_object_files <<  Assembly::ObjectFile.new(File.join(object_folder,File.basename(object_file['Filename'])),:label=>object_file['Label']) }
        
      params={:druid=>druid,:objects=>content_object_files,:add_exif=>false,:style=>cm_style.to_sym}        
      content_md_xml = Assembly::ContentMetadata.create_content_metadata(params)
      File.open(cm_file, 'w') { |fh| fh.puts content_md_xml } 
      puts "Writing content metadata file #{cm_file} for #{druid} and object #{object}"

    else

      puts "ERROR: Did not create content metadata file #{cm_file} -- missing druid or no files found"
    
    end # end check for a druid and files
    
  end # end loop over all output log file
  
  puts ""
  
# either a report or copy operation
else 
  
  FileUtils.cd(base_content_folder)
  
  csv_data.each do |row|

    n+=1
    puts "Row #{n} out of #{csv_data.size}"
    $stdout.flush
  
    object=row['Object'].gsub(',','-') # commas are no good in filenames, use a dash instead
    row_filename=row['Image']
    label=row['Label']
    sequence=row['Sequence']
    druid=row['Druid']
  
    filename=File.basename(row_filename,File.extname(row_filename)) # remove any extension from the filename that was provided
  
    if log_file_data.select {|row| row["Image"] == row_filename && row["Success"] == "true" }.size == 0 # check to see if we have already successfully run this file
    
      object_folder=File.join(staging_folder,object)

      unless found_objects.include? object # we have a new object
        FileUtils.mkdir_p object_folder unless report
        found_objects << object
        puts "...#{Time.now}: Found new object: '#{object}', creating object folder '#{object_folder}'"
        num_objects+=1
      end # end we have an object

      # now search for file
      puts "......#{Time.now}: looking for file '#{filename}', label '#{label}'"
      search_string="find . -name #{filename}.* -print"
      search_result=`#{search_string}`
      files=search_result.split(/\n/)
  
      # if found, copy first file to staging directory (if it does not exist)
      if files.size > 0
        input_file=files[0]
        message= "found #{input_file}, copying to object folder #{object_folder}"
        input_filename=File.basename(files[0])
        output_file=File.join(object_folder,input_filename)
        FileUtils.cp input_file, output_file unless (report || File.exists?(output_file))
        num_files_copied+=1
        success=true
      else
        message="ERROR #{filename} NOT FOUND"
        num_files_not_found+=1
        success=false
      end

      CSV.open(csv_out, 'a') {|f| 
        output_row=[object,filename,input_filename,sequence,label,druid,success,message,Time.now]
        f << output_row
      }  

      puts "......#{message}"
      puts ""
      $stdout.flush  
  
    else
    
      puts "......#{Time.now}: skipping #{object} - already run"
       
    end # end check to see if we have already successfully run this filename
  
  end # end loop over all rows

  puts ""
  puts "Total objects staged: #{num_objects}"
  puts "Total files copied: #{num_files_copied}"
  puts "Total files not found: #{num_files_not_found}"
  
end # end check for content metadata or copying/report

puts "Completed at #{Time.now}, total time was #{'%.2f' % ((Time.now - start_time)/60.0)} minutes"