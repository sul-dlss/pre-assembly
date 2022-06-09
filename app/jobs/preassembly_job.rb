# frozen_string_literal: true

class PreassemblyJob < ApplicationJob
  queue_as :preassembly

  # @param [JobRun] job_run
  def perform(job_run)
    job_run.started
    batch = job_run.batch_context.batch
    # the .run_pre_assembly is where all the work occurs
    batch.run_pre_assembly
    if batch.objects_had_errors # this is when errors occur on individual objects when running the report
      job_run.error_message = batch.error_message
      job_run.completed_with_errors
    else
      job_run.completed
    end
  rescue StandardError => e # this catches an exception that occurs on the entire job
    job_run.error_message = e.message
    job_run.failed
  end
end
