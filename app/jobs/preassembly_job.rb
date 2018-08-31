class PreassemblyJob < ApplicationJob
  # queue_as :preassembly

  def perform(*args)
    logger.info("PreassemblyJob perform method doesn't do anything yet")
  end
end
