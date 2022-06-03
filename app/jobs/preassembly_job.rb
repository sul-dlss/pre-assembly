# frozen_string_literal: true

class PreassemblyJob < ApplicationJob
  queue_as :preassembly

  # @param [JobRun] job_run
  def perform(job_run)
    job_run.started
    bc = job_run.batch_context
    result = bc.batch.run_pre_assembly
    result ? job_run.completed : job_run.errored
  end
end
