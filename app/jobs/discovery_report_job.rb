# frozen_string_literal: true

class DiscoveryReportJob < ApplicationJob
  queue_as :discovery_report

  # @param [JobRun] job_run
  def perform(job_run)
    job_run.started
    begin
      report = job_run.to_discovery_report
      file = File.open(report.output_path, 'w') { |f| f << report.to_builder.target! }
      job_run.output_location = file.path # don't call report.output_path again
      job_run.save!
      job_run.completed
    rescue StandardError => e
      job_run.error_message = e.message
      job_run.failed
    end
  end
end
