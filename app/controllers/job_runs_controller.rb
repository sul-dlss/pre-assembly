class JobRunsController < ApplicationController
  def index
    flash[:notice] = "Success! Your job is queued. A link to your validation report will be emailed to you when it is ready." if params[:created]
    @job_runs = JobRun.order('created_at desc').page params[:page]
  end

  def show
    @job_run = JobRun.find(params[:id])
  end

  def download
    @job_run = JobRun.find(params[:id])
    if @job_run.output_location
      send_file @job_run.output_location
    else
      flash[:notice] = 'Job is not complete. Please check back later.'
      render 'show'
    end
  end
end
