# frozen_string_literal: true

class DiscoveryReportJob < ApplicationJob
  # @param [JobRun] job_run
  # rubocop:disable Metrics/AbcSize
  def perform(job_run)
    job_run.started
    report = job_run.to_discovery_report
    # .to_builder produces JSON report by iterating over the objects
    # Note: It is required to parse the JSON first in order to correctly pretty print it
    file = File.open(report.output_path, 'w') { |f| f << JSON.pretty_generate(JSON.parse(report.to_builder.target!)) }
    job_run.output_location = file.path
    job_run.save!
    job_run.error_message = report.objects_had_errors? ? report.error_message : nil
    job_run.completed
  rescue StandardError => e # catch any error preventing the whole job from running (e.g. bad header in csv)
    job_run.error_message = e.exception
    job_run.failed
  end
  # rubocop:enable Metrics/AbcSize
end
