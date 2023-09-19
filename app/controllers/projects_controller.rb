# frozen_string_literal: true

class ProjectsController < ApplicationController
  def index
    @projects = Project.order(:created_at).page(params[:page])
  end

  def show
    @project = Project.find(params[:id])
  end

  def new
    @project = Project.new(
      job_runs: [JobRun.new]
    )
  end

  def create
    @project = Project.new(project_params)
    if @project.save
      flash[:success] = 'Success! Your job is queued. A link to job output will be emailed to you upon completion.'
      redirect_to controller: 'job_runs', status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def project_params
    params.require(:project)
          .permit(:project_name, :content_structure, :staging_style_symlink,
                  :processing_configuration, :staging_location, :all_files_public,
                  :using_file_manifest, job_runs_attributes: [:job_type])
          .merge(user: current_user)
  end
end
