# with an argo report, look to be sure accessionWF sdr-ingest-transfer is complete, and if so, set accession2WF step to completed too
# run with
# ruby devel/workflow_cleanup.rb argo_report.csv

ENV['ROBOT_ENVIRONMENT'] = 'production' # environment to run under (i.e. which fedora instance to hit)

step = 'sdr-ingest-transfer' # the step to look at
workflow_to_fix = 'accession2WF' # the workflow that needs its step set to completed from waiting
reference_workflow = 'accessionWF' # the workflow to check against to be sure it is completed

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')

abort "Incorrect N of arguments." unless ARGV.size == 1
csv_in = ARGV[0]

# read input manifest
csv_data = RevsUtils.read_csv_with_headers(csv_in)
total = csv_data.size

start_time = Time.now
puts ""

n = 0
fixed = 0
not_fixed = 0

puts "Read data from #{csv_in}"
puts "Found #{total} druids"
puts "Look for #{workflow_to_fix}:#{step} in waiting and #{reference_workflow}:#{step} in completed, will set both to completed"
puts "Started at #{start_time}"

csv_data.each do |row|
  n += 1

  pid = row['Druid']
  druid = "druid:#{pid}"

  msg = "#{n} of #{total}: #{druid}"
  if Dor::Config.workflow.client.get_workflow_status('dor', druid, reference_workflow, step) == 'completed' && Dor::Config.workflow.client.get_workflow_status('dor', druid, workflow_to_fix, step) == 'waiting'
    Dor::Config.workflow.client.update_workflow_status 'dor', druid, workflow_to_fix, step, "completed"
    puts "#{msg}: Set #{workflow_to_fix}:#{step} to completed"
    fixed += 1
  else
    puts "#{msg}: No action taken"
    not_fixed += 1
  end
end

puts ""
puts "#{fixed} fixed, #{not_fixed} not fixed"
puts "Completed at #{Time.now}, total time was #{'%.2f' % ((Time.now - start_time) / 60.0)} minutes"
