# Given the full path to a folder containing pre-assembly YAML files, iterate through, find any YAML files, and then attempt
# to run discovery reports for all found

# You will want to run in nohup mode for a large set, and this will take a long time

# Peter Mangiafico
# April 9, 2015
#
# Run with
# ROBOT_ENVIRONMENT=production nohup ruby devel/revs_run_discovery_reports.rb /dor/staging/Revs > discovery_reports.log & # supply folder to iterate over

help "Incorrect N of arguments." if ARGV.size != 1
input = ARGV[0]

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')

if File.directory?(input)

  puts ""
  puts 'revs_run_discovery_reports'
  puts "Started at #{Time.now}"
  puts "Input: #{input}"
  puts "Searching for YAML files..."

  start_time = Time.now

  FileUtils.cd(input)
  files = Dir.glob("**/**.yaml") + Dir.glob("**/**.YAML") # look for all yaml config files
  files.sort!
  files.reject! { |file| file.include?("$RECYCLE.BIN") } # ignore stuff in the trash

  num_errors = 0
  counter = 0
  num_files = files.count

  puts "Found #{num_files} yaml files to process"
  puts ""

  files.each do |file|
    counter += 1
    full_path_to_yaml = File.join(input, file) # fully qualified path to yaml file

    puts "#{counter} of #{num_files} : working on #{file}"

    params = YAML.load(File.read full_path_to_yaml)
    params['config_filename'] = full_path_to_yaml
    report_params = { :confirm_checksums => true, :show_other => true, :show_smpl_cm => false, :show_stage => false, :no_check_reg => false, :check_sourceids => false }

    begin
      b = PreAssembly::Bundle.new params
      b.discovery_report(report_params)
    rescue Exception => e
      puts "*** ERROR: #{e.message}"
    end

    puts ""
    puts ""
  end

  puts ""
  puts "Completed at #{Time.now}, total time was #{'%.2f' % ((Time.now - start_time) / 60.0)} minutes"

else

  puts "Error: #{input} is not a directory"

end

puts ''
