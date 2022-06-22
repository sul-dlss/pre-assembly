# frozen_string_literal: true

require 'csv'

# rubocop:disable Metrics/BlockLength
namespace :reports do
  # Output statistics on all discovery reports available on disk
  desc 'Disovery report analytics'
  task discovery: :environment do
    output_file = 'tmp/discovery_report_stats.csv'
    total = JobRun.where(job_type: 'discovery_report').count
    num_found = 0
    num_not_found = 0
    puts "Running discovery report analytics for #{total} discovery report job runs"
    CSV.open(output_file, 'w') do |csv|
      csv << %w[num_objects num_files num_errors runtime_minutes user report_date]
      JobRun.where(job_type: 'discovery_report').each.with_index(1) do |job_run, i|
        puts "#{i} of #{total}"
        if job_run.output_location && File.exist?(job_run.output_location)
          num_found += 1
          json_report = JSON.parse(File.read(job_run.output_location))
          num_objects = json_report['rows'].count
          num_errors = json_report['summary']['objects_with_error']
          start_time = json_report['summary']['start_time'].to_datetime
          end_time = if json_report['summary']['end_time'].nil?
                       # fallback to file modification date if no end_time in json summary
                       File.mtime(job_run.output_location)
                     else
                       json_report['summary']['end_time'].to_datetime
                     end
          runtime_minutes = (end_time - start_time) / 60.0
          num_files = json_report['summary']['mimetypes'].sum { |_k, v| v }
          csv << [num_objects, num_files, num_errors, runtime_minutes.round(2), job_run.batch_context.user.sunet_id, job_run.updated_at.to_date.to_s]
        else
          num_not_found += 1
        end
      end
    end
    puts "Total: #{total}.  Reports found: #{num_found}.  Reports not found: #{num_not_found}.  Report written to #{output_file}"
  end
end
# rubocop:enable Metrics/BlockLength
