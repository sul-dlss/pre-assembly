# Used to stage content from Rumsey format to folder structure ready for accessioning.
# Iterate through each row in the manifest, find files, generate contentMetadata and symlink to new location.

# Peter Mangiafico
# June 17, 2015
#
# Run with
# ROBOT_ENVIRONMENT=production ruby devel/prepare_rumsey.rb /maps/ThirdParty/Rumsey/Rumsey_Batch1.csv [--report] [--content-metadata] [--content-metadata-style map]

# this will only run on lyberservices-prod since it needs access to the MODs template and mods remediation file
#  input CSV should have columns labeled "Object", "Image", and "Label"
#   image is the filename, object is the object identifier (turned into a folder)
#
# if you set the --report switch, it will only produce the output report, it will not symlink any files
# if you set the --content-metadata switch, it will only generate content metadata for each object using the log file for successfully found files, assuming you also have columns in your input CSV labeled "Druid", "Sequence" and "Label"

# parameters:
base_content_folder='/maps/ThirdParty/Rumsey/content' # base folder to search for content
staging_folder='/maps/ThirdParty/Rumsey/Batch4B/staging' # location to stage content to
# base_content_folder='/Users/petucket/Downloads' # base folder to search for content
# staging_folder='/Users/petucket/Downloads/staging' # location to stage content to

content_metadata_filename='contentMetadata.xml'

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')
require 'optparse'

report=false # if set to true, will only show output and produce report, won't actually symlink files or create anything, can be overriden with --report switch
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

# either a report or symlink operation
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

    success=false

    filename=File.basename(row_filename,File.extname(row_filename)) # remove any extension from the filename that was provided

    previously_found=(log_file_data.select {|row| row["Image"] == row_filename && row["Success"].downcase == "true" }.size) > 0
    previously_missed=(log_file_data.select {|row| row["Image"] == row_filename && row["Success"].downcase == "false" }.size) > 0

    unless previously_found # only look for this file if it has not already been found according to the log file

      object_folder=File.join(staging_folder,object)

      unless found_objects.include? object # we have a new object
        FileUtils.mkdir_p object_folder unless report
        found_objects << object
        puts "...#{Time.now}: Found new object: '#{object}', creating object folder '#{object_folder}' if needed"
        num_objects+=1
      end # end we have an object

      # now search for any file which ends with the filename (trying to catch cases where the filename has 0s at the beginning that were dropped from the spreadsheet)
      puts "......#{Time.now}: looking for file '#{filename}', object '#{object}', label '#{label}'"
      search_string="find . -iname '*#{filename}.*' -type f -print"
      search_result=`#{search_string}`
      files=search_result.split(/\n/)

      # if found, symlink files that match or that end with the filename but have any number of leading zeros
      if files.size > 0
        files.each do |input_file|
          input_filename=File.basename(input_file)
          input_filename_without_ext=File.basename(input_file,File.extname(input_file))
          input_filename_leading_zeros=/^[0]*/.match(input_filename)[0].size
          if (input_filename_without_ext == filename) || (input_filename_leading_zeros > 0) # if the found file is an exact match with the data provided OR if it ends with the string and starts with leading zeros, symlink it
            message= "found #{input_file}, symlink to object folder #{object_folder} (#{input_filename_leading_zeros} filename leading zeros)"
            output_file=File.join(object_folder,input_filename)
            FileUtils.ln_s(input_file, output_file,:force=>true) unless (report || File.exists?(output_file))
            num_files_copied+=1
            success=true
            CSV.open(csv_out, 'a') {|f|
              output_row=[object,filename,input_filename,sequence,label,druid,success,message,Time.now]
              f << output_row
            }
            puts "......#{message}"
          end # end check for matching filename
        end # end loop over all matches

      end # end check for files.size > 0

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
  puts "Total files not found: #{num_files_not_found}"

end # end check for content metadata or symlinking/report

puts "Completed at #{Time.now}, total time was #{'%.2f' % ((Time.now - start_time)/60.0)} minutes"
