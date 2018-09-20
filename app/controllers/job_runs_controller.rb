class JobRunsController < ApplicationController
  def show
    @job_run = JobRun.find(params[:id])
  end
end
