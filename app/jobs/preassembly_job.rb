# frozen_string_literal: true

class PreassemblyJob < ApplicationJob
  queue_as :preassembly

  # @param [JobRun] job_run
  def perform(job_run)
    bc = job_run.batch_context
    bc.bundle.run_pre_assembly
    job_run.output_location = bc.progress_log_file
    job_run.save!
  end
end
