# frozen_string_literal: true

class JobMailer < ApplicationMailer
  default from: 'no-reply-preassembly-job@stanford.edu'

  def completion_email
    @job_run = params[:job_run]
    @user = @job_run.batch_context.user

    # This email is sent when either (1) a discovery report completes, or (2) a preassembly job ends with errors
    # If the preassembly job completes with no errors (and items are accessioning), a separate email is instead sent
    # when accessioning is complete.
    @subject = "[#{@job_run.batch_context.project_name}] Your #{@job_run.job_type.humanize} job "
    @subject += @job_run.job_type == 'preassembly' ? 'encountered an error' : 'completed'
    mail(
      to: @user.email,
      subject: @subject
    )
  end

  def accession_completion_email
    @job_run = params[:job_run]
    @user = @job_run.batch_context.user
    @completed_accessions = @job_run.accessions.where(state: 'completed')
    @failed_accessions = @job_run.accessions.where(state: 'failed')
    mail(
      to: @user.email,
      subject: "[#{@job_run.batch_context.project_name}] Job completed"
    )
  end
end
