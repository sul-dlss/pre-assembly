# frozen_string_literal: true

class DiscoveryReportJob < ApplicationJob
  queue_as :discovery_report

  # @param [JobRun] job_run
  # rubocop:disable Metrics/AbcSize
  def perform(job_run)
    job_run.started
    report = job_run.to_discovery_report
    # the .to_builder is where all the work of the report happens, it iterates over the objects and produces JSON
    file = File.open(report.output_path, 'w') { |f| f << report.to_builder.target! }
    job_run.output_location = file.path
    job_run.save!
    if report.objects_had_errors # this is when errors occur on individual objects when running the report
      job_run.error_message = report.error_message
      job_run.completed_with_errors
    else
      job_run.completed
    end
  rescue StandardError => e # this catches an exception that occurs on the entire job
    job_run.error_message = e.message
    job_run.failed
  end
  # rubocop:enable Metrics/AbcSize
end
