# Given the full path to a csv file manifest, it will check for a "hide" column, add it if not found, then set the value to "yes" for all rows
# to prepare the manifest to have all images hidden once accessioned.

# Peter Mangiafico
# April 8, 2015
#
# Run with
# ruby devel/revs_hide_images_in_manifest.rb /dor/staging/Revs/BoxXX/path_to_manifest.csv  # supply path to csv manifest that needs all of its images hidden

help "Incorrect N of arguments." if ARGV.size != 1
input = ARGV[0]

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')
require 'csv'

if File.file?(input) 

    puts ""
    puts 'revs_hide_images_in_manifest'
    puts "Started at #{Time.now}"
    puts "Input: #{input}"
    start_time=Time.now

    new_file=input + '.hidden'
    
    file_contents = IO.read(input)
    input_csv = CSV.parse(file_contents, :headers => true)

    headers=input_csv.headers
    headers << 'hide' unless headers.include?('hide') # we don't have the hide column yet, we need to add it

    input_csv_rows = input_csv.map { |row| row.to_hash.with_indifferent_access }

    # start creating new file
    CSV.open(new_file, "w:UTF-8",{:force_quotes=>true}) do |output_csv|
        output_csv << headers
        
        input_csv_rows.each do |row|
        
            row.update({'hide'=>'yes'}) # make sure the hide column is set to yes
            output_csv << row.values # write out the new row
        
        end
        
    end
    
    FileUtils.mv input,input+'.old' # save the old version
    FileUtils.mv new_file,input # rename the new version to the original

    puts ""
    puts "Original file at: #{input+'.old'}"
    puts "Completed at #{Time.now}, total time was #{Time.now - start_time}"
  
else
  
  puts "Error: #{input} is not a file"
  
end


puts ''