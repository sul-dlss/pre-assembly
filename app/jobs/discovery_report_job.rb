# frozen_string_literal: true

class DiscoveryReportJob < ApplicationJob
  queue_as :discovery_report

  # @param [JobRun] job_run
  # rubocop:disable Metrics/AbcSize
  def perform(job_run)
    job_run.started
    report = job_run.to_discovery_report
    file = File.open(report.output_path, 'w') { |f| f << report.to_builder.target! }
    job_run.output_location = file.path # don't call report.output_path again
    job_run.save!
    if report.had_errors
      job_run.error_message = report.error_message
      job_run.completed_with_errors
    else
      job_run.completed
    end
  rescue StandardError => e
    job_run.error_message = e.message
    job_run.failed
  end
  # rubocop:enable Metrics/AbcSize
end
