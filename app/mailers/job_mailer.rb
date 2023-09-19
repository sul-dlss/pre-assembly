# frozen_string_literal: true

class JobMailer < ApplicationMailer
  default from: 'no-reply-preassembly-job@stanford.edu'

  def completion_email
    @job_run = params[:job_run]
    @user = @job_run.batch_context.user
    @completed_accessions = completed_accessions
    @failed_accessions = failed_accessions
    mail(to: @user.email, subject: @job_run.mail_subject)
  end

  def completed_accessions
    @job_run.accessions.where(state: 'completed')
  end

  def failed_accessions
    @job_run.accessions.where(state: 'failed')
  end
end
