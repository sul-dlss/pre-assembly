class BundleContextController < ApplicationController
  def index
    @bundle_context = BundleContext.new
  end

  def create
    @bundle_context = BundleContext.new(bundle_context_params)

    # TODO: ticket #270 user should be authenticated as saved in AR
    user = User.create(sunet_id: 'temp')

    @bundle_context.user = user
    if @bundle_context.save
      # TODO: ticket #267 Choose type of job (DiscoveryReport or Pre-Assembly) using params[:job_selection]
      PreassemblyJob.perform_later
    else
      render :index
    end
  end

  private

  def bundle_context_params
    params.permit(:project_name, :content_structure, :content_metadata_creation, :bundle_dir)
  end
end
