# frozen_string_literal: true

class BatchContextsController < ApplicationController
  def new
    @batch_context = BatchContext.new(
      job_runs: [JobRun.new],
      content_structure: 'simple_image',
      content_metadata_creation: 'default',
      using_file_manifest: false
    )
  end

  def create
    @batch_context = BatchContext.new(batch_contexts_params)
    if @batch_context.save
      flash[:success] = 'Success! Your job is queued. A link to job output will be emailed to you upon completion.'
      redirect_to controller: 'job_runs'
    else
      render :new
    end
  end

  def index
    @batch_contexts = BatchContext.order(:created_at).page(params[:page])
  end

  def show
    @batch_context = BatchContext.find(params[:id])
  end

  private

  def batch_contexts_params
    params.require(:batch_context)
          .permit(:project_name, :content_structure, :staging_style_symlink,
                  :content_metadata_creation, :bundle_dir, :all_files_public,
                  :using_file_manifest, job_runs_attributes: [:job_type])
          .merge(user: current_user)
  end
end
