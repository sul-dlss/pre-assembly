class JobMailer < ApplicationMailer
  default from: 'no-reply-preassembly-job@stanford.edu'

  def completion_email
    @job = params[:job_run]
    @user = @job.bundle_context.user
    mail(to: @user.email, subject: 'Your pre-assembly job has completed')
  end

end
