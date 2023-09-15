# frozen_string_literal: true

class PreassemblyJob < ApplicationJob
  # @param [JobRun] job_run
  def perform(job_run)
    job_run.started
    batch = job_run.batch
    # .run_pre_assembly iterates over all objects and runs preassembly on each
    batch.run_pre_assembly
    if batch.objects_had_errors # individual objects processed had errors
      job_run.error_message = batch.error_message
      job_run.preassembly_completed_with_errors
    else
      job_run.preassembly_completed
    end
    # To avoid a possible race condition, run JobrunCompleteJob.
    JobRunCompleteJob.perform_later(job_run)
  rescue StandardError => e # catch any error preventing the whole job from running (e.g. bad header in csv)
    job_run.error_message = e.exception
    job_run.failed
  end
end
