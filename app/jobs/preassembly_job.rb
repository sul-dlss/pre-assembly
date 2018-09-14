class PreassemblyJob < ApplicationJob
  queue_as :preassembly

  # @param [JobRun] job_run
  def perform(job_run)
    logger.info("PreassemblyJob perform method doesn't do anything yet")
  end
end
