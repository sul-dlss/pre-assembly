# frozen_string_literal: true

class BatchContextsController < ApplicationController
  def index
    @batch_contexts = BatchContext.order(:created_at).page(params[:page])
  end

  def show
    @batch_context = BatchContext.find(params[:id])
  end

  def new
    @batch_context = BatchContext.new(
      job_runs: [JobRun.new]
    )
  end

  def create
    @batch_context = BatchContext.new(batch_contexts_params)
    if @batch_context.save
      flash[:success] = 'Success! Your job is queued. A link to job output will be emailed to you upon completion.'
      redirect_to controller: 'job_runs', status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def batch_contexts_params
    params.require(:batch_context)
          .permit(:project_name, :content_structure, :staging_style_symlink,
                  :content_metadata_creation, :staging_location, :all_files_public,
                  :using_file_manifest, job_runs_attributes: [:job_type])
          .merge(user: current_user)
  end
end
