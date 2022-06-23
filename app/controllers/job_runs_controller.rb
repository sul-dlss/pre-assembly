# frozen_string_literal: true

class JobRunsController < ApplicationController
  def create
    raise ActionController::ParameterMissing, :batch_context_id unless job_run_params[:batch_context_id]

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
    return render 'recent_history' if request.headers['Turbo-Frame']
  end

  def show
    @job_run = JobRun.find(params[:id])
  end

  def download_log
    @job_run = JobRun.find(params[:id])
    if @job_run.progress_log_file && File.exist?(@job_run.progress_log_file)
      send_file @job_run.progress_log_file
    else
      flash[:warning] = 'Progress log file not available.'
      render 'show'
    end
  end

  def download_report
    @job_run = JobRun.find(params[:id])
    if @job_run.output_location && File.exist?(@job_run.output_location)
      send_file @job_run.output_location
    else
      flash[:warning] = 'Job is not complete. Please check back later.'
      render 'show'
    end
  end

  def discovery_report_summary
    job_run = JobRun.find(params[:id])
    if job_run.output_location && File.exist?(job_run.output_location)
      @discovery_report = JSON.parse(File.read(job_run.output_location))
    else
      flash[:warning] = 'Discovery report file is not available.'
      render 'show'
    end
  end

  private

  def job_run_params
    params.require(:job_run).permit(:batch_context_id, :job_type)
  end
end
