class TemplateController < ApplicationController

  def index
  end

  def create
    logger.debug("TemplateController.create called")
    PreassemblyJob.perform_later
  end

end
