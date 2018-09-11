class DiscoveryReportJob < ApplicationJob
  queue_as :discovery_report

  def perform(*args)
    logger.info("DiscoveryReportJob perform method doesn't do anything yet")
  end
end
