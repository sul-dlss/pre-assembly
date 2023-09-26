# frozen_string_literal: true

class PreassemblyJob < ApplicationJob
  # @param [JobRun] job_run
  def perform(job_run)
    job_run.started
    batch = job_run.batch
    # .run_pre_assembly iterates over all objects and runs preassembly on each
    batch.run_pre_assembly
    job_run.error_message = batch.objects_had_errors ? batch.error_message : nil
    job_run.completed
    # To avoid a possible race condition (all accessioning complete before job run is marked completed),
    # run JobrunCompleteJob.
    JobRunCompleteJob.perform_later(job_run)
  rescue StandardError => e # catch any error preventing the whole job from running (e.g. bad header in csv)
    job_run.error_message = e.exception
    job_run.failed
  end
end
