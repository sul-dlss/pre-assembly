# frozen_string_literal: true

class JobRunsController < ApplicationController
  def index
    @job_runs = JobRun.order('created_at desc').page params[:page]
    render 'recent_history' if request.headers['Turbo-Frame']
  end

  def show
    @job_run = JobRun.find(params[:id])
    @discovery_report = JSON.parse(File.read(@job_run.output_location)) if @job_run.report_ready?
    @structural_has_changed = structural_changed?
  end

  def create
    raise ActionController::ParameterMissing, :batch_context_id unless job_run_params[:batch_context_id]

    @job_run = JobRun.new(job_run_params)
    if @job_run.save
      flash.now[:success] = 'Success! Your job is queued. A link to job output will be emailed to you upon completion.'
    else
      flash.now[:error] = "Error(s) saving JobRun: #{@job_run.errors}"
    end
    redirect_to(action: 'index')
  end

  def download_log
    @job_run = JobRun.find(params[:id])
    if @job_run.progress_log_file && File.exist?(@job_run.progress_log_file)
      send_file @job_run.progress_log_file
    else
      flash.now[:warning] = 'Progress log file not available.'
      render 'show'
    end
  end

  def download_report
    @job_run = JobRun.find(params[:id])
    if @job_run.output_location
      send_file @job_run.output_location
    else
      flash.now[:warning] = 'Job is not complete. Please check back later.'
      render 'show'
    end
  end

  private

  def job_run_params
    params.require(:job_run).permit(:batch_context_id, :job_type)
  end

  # This method is used to determine if any rows in the discovery report include file changes.
  # Consider extracting to a service object if we would like to enhance test coverage.
  def structural_changed?
    return false unless @discovery_report

    @discovery_report['rows']&.any? { |druid| druid.key?('file_diffs') }
  end
end
