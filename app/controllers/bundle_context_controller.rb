class BundleContextController < ApplicationController

  def index
  end

  def create
    logger.debug("BundleContextController.create called")
    PreassemblyJob.perform_later
  end

end
