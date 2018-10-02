class JobRunsController < ApplicationController
  def create
    raise ActionController::ParameterMissing, :bundle_context_id unless job_run_params[:bundle_context_id]
    @job_run = JobRun.new(job_run_params)
    if @job_run.save
      flash[:success] = 'Success! Your job is queued. A link to job output will be emailed to you upon completion.'
    else
      flash[:error] = "Error(s) saving JobRun: #{@job_run.errors}"
    end
    redirect_to(action: 'index')
  end

  def index
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
      flash[:warning] = 'Job is not complete. Please check back later.'
      render 'show'
    end
  end

  private

  def job_run_params
    params.require(:job_run).permit(:bundle_context_id, :job_type)
  end
end
