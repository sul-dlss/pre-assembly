class DiscoveryReportJob < ApplicationJob
  queue_as :discovery_report

  # @param [JobRun] job_run
  def perform(job_run)
    logger.info("DiscoveryReportJob perform method doesn't do anything yet")
  end
end
