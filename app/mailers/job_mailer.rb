# frozen_string_literal: true

class JobMailer < ApplicationMailer
  default from: 'no-reply-preassembly-job@stanford.edu'

  def completion_email
    @job_run = params[:job_run]
    @user = @job_run.batch_context.user
    mail(
      to: @user.email,
      subject: "[#{@job_run.batch_context.project_name}] Your #{@job_run.job_type.humanize} job completed"
    )
  end

  def accession_completion_email
    @job_run = params[:job_run]
    @user = @job_run.batch_context.user
    @completed_accessions = @job_run.accessions.where(state: 'completed')
    @failed_accessions = @job_run.accessions.where(state: 'failed')
    mail(
      to: @user.email,
      subject: "[#{@job_run.batch_context.project_name}] Accessioning completed"
    )
  end
end
