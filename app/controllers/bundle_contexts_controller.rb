class BundleContextsController < ApplicationController
  def index
    @bundle_context = BundleContext.new(job_runs: [JobRun.new(job_type: "preassembly")], content_structure: "simple_image", content_metadata_creation: "default")
  end

  def create
    @bundle_context = BundleContext.new(bundle_contexts_params)
    if @bundle_context.save
      render :create
    else
      render :index
    end
  end

  private

  def bundle_contexts_params
    params.require(:bundle_context).permit(:project_name, :content_structure, :staging_style_symlink, :content_metadata_creation, :bundle_dir, job_runs_attributes: [:job_type])
          .merge(user: current_user)
  end
end
