# Used to stage content from Rumsey or other similar format to folder structure ready for accessioning.
# This script is only known to be used by the Maps Accessioning team (Rumsey Map Center) on sul-lyberservices-prod
# Full documentation of how it is used is here (which needs to be updated if this script moves):
# https://consul.stanford.edu/pages/viewpage.action?pageId=146704638

# Iterate through each row in the supplied CSV manifest, find files, generate contentMetadata and symlink to new location.
# Note: filenames must match exactly (no leading 0s) but can be in any sub-folder

# Peter Mangiafico
# November 14, 2017
#
# Run with
# ROBOT_ENVIRONMENT=production ruby devel/prepare_content.rb INPUT_CSV_FILE.csv FULL_PATH_TO_CONTENT FULL_PATH_TO_STAGING_AREA [--no-object-folders] [--report] [--content-metadata] [--content-metadata-style map]
#  e.g.
# ROBOT_ENVIRONMENT=production ruby devel/prepare_content.rb /maps/ThirdParty/Rumsey/Rumsey_Batch1.csv /maps/ThirdParty/Rumsey/content /maps/ThirdParty/Rumsey [--no-object-folders] [--report] [--content-metadata] [--content-metadata-style map]

# the first parameter is the input CSV (with columns labeled "Object", "Image", and "Label" (image is the filename, object is the object identifier which can be turned into a folder)
# second parameter is the full path to the content folder that will be searched (i.e. the base content folder)
#      Note: files will be searched iteratively through all sub-folders of the base content folder
# third parameter is optional and is the full path to a folder to stage (i.e. symlink) content to - if not provided, will use same path as csv file, and append "staging"
#
# if you set the --report switch, it will only produce the output report, it will not symlink any files
# if you set the --content-metadata switch, it will only generate content metadata for each object using the log file for successfully found files, assuming you also have columns in your input CSV labeled "Druid", "Sequence" and "Label"
# if you set the --no-object-folders switch, then all symlinks will be flat in the staging directory (i.e. no object level folders) -- this requires all filenames to be unique across objects, if left off, then object folders will be created to store symlinks
# note that file extensions do not matter when matching

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')
require 'optparse'
require 'pathname'

content_metadata_filename = 'contentMetadata.xml'
report = false # if set to true, will only show output and produce report, won't actually symlink files or create anything, can be overriden with --report switch
content_metadata = false # if set to true, will also generate content-metadata from values supplied in spreadsheet, can be set via switch
cm_style = 'map' # defaults to map type content metadata unless overriden
no_object_folders = false # if false, then each new object will be in a separately created folder, with symlinks contained inside it; if true, you will get a flat list


help="Usage:\n    ruby prepare_content.rb INPUT_CSV_FILE BASE_CONTENT_FOLDER [STAGING_FOLDER] [--no-object-folders] [--report] [--content_metadata] [--content_metadata_style STYLE]\n"
OptionParser.new do |opts|
  opts.banner = help
  opts.on("--report") do |dr|
    report=true
  end
  opts.on("--content_metadata") do |cm|
    content_metadata=true
  end
  opts.on("--content_metadata_style [STYLE]") do |st|
    cm_style=st
  end
  opts.on("--no-object-folders") do |ob|
    no_object_folders=true
  end
end.parse!

if ARGV.size < 2
  puts help
  abort "Incorrect number of argument provided - you need to supply an input CSV file and the folder to search for."
end
csv_in = ARGV[0]
base_content_folder = ARGV[1]

source_path=File.dirname(csv_in)
source_name=File.basename(csv_in,File.extname(csv_in))
csv_out=File.join(source_path, source_name + "_log.csv")

if ARGV.size == 2 # no staging path provided, use same as CSV In and append "staging"
  staging_folder = File.join(source_path,"staging")
else # use what was provided
  staging_folder = ARGV[2]
end

abort "#{csv_in} not found" unless File.exists?(csv_in)

unless File.exists?(csv_out) # if we don't already have a log file, write out the header row
  CSV.open(csv_out, 'a') {|f|
    output_row=["Object","Image","Filename","Sequence","Label","Druid","Success","Message","Time"]
    f << output_row
  }
end

# read in existing log file
log_file_data = CSV.parse(IO.read(csv_out), :headers => true).map { |row| row.to_hash.with_indifferent_access }

# read input manifest
csv_data = CSV.parse(IO.read(csv_in), :headers => true).map { |row| row.to_hash.with_indifferent_access }

start_time=Time.now
puts ""
puts "***Prepare Content***"
puts "Only producing report" if report
puts "Producing content metadata with style '#{cm_style}'" if content_metadata
puts "Creating object folders" unless no_object_folders
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

else # either a report or symlink operation

  FileUtils.cd(base_content_folder)
  FileUtils.mkdir_p staging_folder unless report
  files_to_search = Dir.glob("**/**")
  files_to_search.reject!{|f| f == '.' || f == '..' || f == '.DS_Store'}

  csv_data.each do |row|

    n+=1
    puts "Row #{n} out of #{csv_data.size}"
    $stdout.flush

    object=row['Object'].gsub(',','-') # commas are no good in filenames, use a dash instead
    row_filename=row['Image']
    label=row['Label']
    sequence=row['Sequence']
    druid=row['Druid']

    success=false

    filename=File.basename(row_filename,File.extname(row_filename)) # remove any extension from the filename that was provided

    previously_found=(log_file_data.select {|row| row["Image"] == row_filename && row["Success"].downcase == "true" }.size) > 0
    previously_missed=(log_file_data.select {|row| row["Image"] == row_filename && row["Success"].downcase == "false" }.size) > 0

    unless previously_found # only look for this file if it has not already been found according to the output log file

      object_folder=File.join(staging_folder,object)

      unless found_objects.include? object # check to see if we have a new object so we can create a new output folder for it
        msg = "...#{Time.now}: Found new object: '#{object}'"
        unless no_object_folders || report
          FileUtils.mkdir_p object_folder
          msg += " - creating object folder '#{object_folder}' if it does not exist"
        end
        found_objects << object
        num_objects+=1
        puts msg
      end # end we have an object

      # now search for any file which ends with the filename (trying to catch cases where the filename has 0s at the beginning that were dropped from the spreadsheet)
      puts "......#{Time.now}: looking for file '#{filename}', object '#{object}', label '#{label}'"
      # this regular expression will look for files that either match exactly (ignoring extension)
      #  or that match exacatly but are in a sub-directory (as indicated by having a path separator, e.g. a "/" right before the filename)
      # e.g. if you are looking for a file called "test.csv", this will match "test", "test.csv", "test.jpg", "dir/test.csv", "dir/test", but NOT "0test", or "dir/0test.jpg"
      files_found = files_to_search.grep(/((.+\/{1}#{filename})|(^#{filename}))\.\S+/i)
      files_found_basenames = files_found.map { |file| File.basename(file) }
      # if found, symlink files that match
      files_found.each do |input_file|
        input_filename = File.basename(input_file)
        message = "found #{input_file}, symlink to object folder #{object_folder}"
        output_file_full_path = no_object_folders ? File.join(staging_folder, input_filename) : (File.join(object_folder, input_filename))
        input_file_full_path = Pathname.new(File.join(base_content_folder, input_file)).cleanpath(true).to_s
        FileUtils.ln_s(input_file_full_path, output_file_full_path, :force => true) unless (report || File.exist?(output_file_full_path))
        num_files_copied += 1
        success = true
        CSV.open(csv_out, 'a') { |f|
          output_row = [object, filename, input_filename, sequence, label, druid, success, message, Time.now]
          f << output_row
        }
        puts "......#{message}"
      end # end loop over all matches

      # do not log if it was previously missed and we missed it again
      if (!previously_missed && !success)
        message="ERROR #{filename} NOT FOUND"
        num_files_not_found+=1
          CSV.open(csv_out, 'a') {|f|
            output_row=[object,filename,'',sequence,label,druid,success,message,Time.now]
            f << output_row
          }
        puts "......#{message}"
      end

      puts ""
      $stdout.flush

    else

      puts "......#{Time.now}: skipping #{object} - already run"

    end # end check to see if we have already successfully run this filename

  end # end loop over all rows

  puts ""
  puts "Total objects staged: #{num_objects}"
  puts "Total files symlinked: #{num_files_copied}"
  puts "Total rows: #{csv_data.size}"
  puts "Total files not found: #{num_files_not_found}"

end # end check for content metadata or symlinking/report

puts "Completed at #{Time.now}, total time was #{'%.2f' % ((Time.now - start_time)/60.0)} minutes"
