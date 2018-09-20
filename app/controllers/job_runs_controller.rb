class JobRunsController < ApplicationController
  def index
    @job_runs = JobRun.order('created_at desc').page params[:page]
  end

  def show
    @job_run = JobRun.find(params[:id])
  end
end
