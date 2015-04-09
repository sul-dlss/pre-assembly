# Given the full path to a folder containing pre-assembly YAML files, iterate through, find any YAML files, and then load up each YAML file, checking for errors
# useful to confirm that the YAML file parameters can find the manifests, content folders, etc. before running discovery reports

# Peter Mangiafico
# April 9, 2015
#
# Run with
# ROBOT_ENVIRONMENT=production ruby devel/revs_validate_yaml_config.rb /dor/staging/Revs # supply folder to iterate over

help "Incorrect N of arguments." if ARGV.size != 1
input = ARGV[0]

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')

if File.directory?(input) 

  puts ""
  puts 'revs_validate_yaml_config'
  puts "Started at #{Time.now}"
  puts "Input: #{input}"
  puts "Searching for YAML files..."
  start_time=Time.now

  FileUtils.cd(input)
  files=Dir.glob("**/**.yaml") + Dir.glob("**/**.YAML") # look for all yaml config files
  files.reject! {|file| file.include?("$RECYCLE.BIN")} # ignore stuff in the trash

  num_errors=0
  counter=0
  num_files=files.count

  puts "Found #{num_files} yaml files to process"
  puts ""
  puts "counter , file , ok"
  
  files.each do |file|
    
    counter += 1 
    full_path_to_yaml = File.join(input,file) # fully qualified path to yaml file
      
    params = YAML.load(File.read full_path_to_yaml)
    params['config_filename'] = full_path_to_yaml
    report_params={:confirm_checksums=>true,:show_other=>true,:show_smpl_cm=>false,:show_stage=>false,:no_check_reg=>false,:check_sourceids=>false}
        
    begin
      b = PreAssembly::Bundle.new params
      ok="true"
    rescue 
      ok=" ** ERROR **"
      num_errors +=1
    end
    
    puts "#{counter} of #{num_files} , #{file} , #{ok}"
    
  end 

  puts ""
  puts "Num files with errors: #{num_errors} out of #{num_files} processed"
  puts "Completed at #{Time.now}, total time was #{Time.now - start_time}"
  
else
  
  puts "Error: #{input} is not a directory"
  
end

puts ''