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
  puts "counter , file , collections, ok"

  files.each do |file|
    counter += 1
    full_path_to_yaml = File.join(input, file) # fully qualified path to yaml file

    params = YAML.load(File.read full_path_to_yaml)
    params['config_filename'] = full_path_to_yaml
    report_params = { :confirm_checksums => true, :show_other => true, :show_smpl_cm => false, :show_stage => false, :no_check_reg => false, :check_sourceids => false }
    collection_names = []

    begin
      b = PreAssembly::Bundle.new params # just load up bundle to see if any errors are thrown
      # now confirm set IDs are valid
      if params['set_druid_id']
        set_druids = (params['set_druid_id'].class == Array ? params['set_druid_id'] : [params['set_druid_id']]) # make sure it is an array
        params['set_druid_id'].each do |set_druid_id|
          d = PreAssembly::Remediation::Item.new(set_druid_id)
          d.get_object
          raise unless [:set, :collection].include? d.object_type
          collection_names << d.fobj.label
        end
      end
      message = "true"
    rescue
      message = " ** PREASSEMBLY PARAMS ERROR OR SET ID NOT A VALID OBJECT **"
      num_errors += 1
    end

    puts "#{counter} of #{num_files} , #{file} , #{collection_names.join('|')}, #{message}"
  end

  puts ""
  puts "Num files with errors: #{num_errors} out of #{num_files} processed"
  puts "Completed at #{Time.now}, total time was #{'%.2f' % ((Time.now - start_time) / 60.0)} minutes"

else

  puts "Error: #{input} is not a directory"

end

puts ''
