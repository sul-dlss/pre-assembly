# frozen_string_literal: true

class PreassemblyJob < ApplicationJob
  queue_as :preassembly

  # @param [JobRun] job_run
  def perform(job_run)
    job_run.started
    batch = job_run.batch_context.batch
    batch.run_pre_assembly
    if batch.had_errors
      job_run.error_message = batch.error_message
      job_run.completed_with_errors
    else
      job_run.completed
    end
  end
end
