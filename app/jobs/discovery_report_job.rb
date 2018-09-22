class DiscoveryReportJob < ApplicationJob
  queue_as :discovery_report

  # @param [JobRun] job_run
  def perform(job_run)
    report = job_run.to_discovery_report
    file = File.open(report.output_path, 'w') { |f| f << report.to_builder.target! }
    job_run.output_location = file.path # don't call report.output_path again
    job_run.save!
  end
end
