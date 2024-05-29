# frozen_string_literal: true

class BatchContextsController < ApplicationController
  def index
    @batch_contexts = BatchContext.order(created_at: :desc).page(params[:page])
  end

  def show
    @batch_context = BatchContext.find(params[:id])
  end

  def new
    @batch_context = BatchContext.new(
      job_runs: [JobRun.new]
    )
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def create
    params = batch_contexts_params
    params[:ocr_languages] ||= []

    # allow the staging location to be a previously created Globus URL or a Globus destination path
    # and then it connects it to the BatchContext being created
    if params[:staging_location].start_with?('https://') || params[:staging_location].start_with?(Settings.globus.directory)
      globus_dest = GlobusDestination.find_with_globus_url(params[:staging_location]) || GlobusDestination.find_with_globus_path(params[:staging_location])
      params[:staging_location] = globus_dest.staging_location if globus_dest
      params[:globus_destination] = globus_dest
    end

    @batch_context = BatchContext.new(params)
    if @batch_context.save
      @batch_context.job_runs.each(&:enqueue!)
      flash[:success] = 'Success! Your job is queued. A link to job output will be emailed to you upon completion.'
      redirect_to controller: 'job_runs', status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  private

  def batch_contexts_params
    params.require(:batch_context)
          .permit(:project_name, :content_structure, :staging_style_symlink,
                  :processing_configuration, :staging_location, :all_files_public,
                  :run_ocr, :manually_corrected_ocr, :ocr_available,
                  :using_file_manifest, job_runs_attributes: [:job_type], ocr_languages: [])
          .merge(user: current_user)
  end
end
