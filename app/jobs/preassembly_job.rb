class PreassemblyJob < ApplicationJob
  queue_as :preassembly

  # @param [JobRun] job_run
  def perform(job_run)
    bc = job_run.bundle_context
    bc.bundle.run_pre_assembly
    # TODO: produce and save a run-specific log file, similar to discovery_report?
    job_run.output_location = bc.progress_log_file
    job_run.save!
  end
end
