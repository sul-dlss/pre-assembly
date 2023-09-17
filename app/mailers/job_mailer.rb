# frozen_string_literal: true

class JobMailer < ApplicationMailer
  default from: 'no-reply-preassembly-job@stanford.edu'

  def completion_error_email
    @job_run = params[:job_run]
    @user = @job_run.batch_context.user
    mail(
      to: @user.email,
      subject: "[#{@job_run.batch_context.project_name}] Your #{@job_run.job_type.humanize} job encountered errors"
    )
  end

  def failed_druids_from_discovery
    @discovery_report['summary']['objects_with_error']
  end
end
