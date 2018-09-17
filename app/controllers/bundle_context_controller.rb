class BundleContextController < ApplicationController
  def index
    @bundle_context = BundleContext.new
  end

  def create
    @bundle_context = BundleContext.create(bundle_context_params)
    if @bundle_context.persisted?
      # TODO: toggle job_type by extra param (#299)
      @job_run = JobRun.create(bundle_context: @bundle_context, job_type: 'discovery_report')
    else
      render :index
    end
  end

  private

  def bundle_context_params
    params.permit(:project_name, :content_structure, :content_metadata_creation, :bundle_dir)
          .merge(user: current_user)
  end
end
