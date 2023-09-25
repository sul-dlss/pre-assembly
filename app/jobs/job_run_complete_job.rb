# frozen_string_literal: true

# Updates a JobRun if all Accessions are complete
class JobRunCompleteJob < ApplicationJob
  def perform(job_run)
    return if job_run.running? ||
              job_run.accessioning_complete? ||
              job_run.accessions.empty? ||
              job_run.accessions.exists?(state: :in_progress)

    job_run.accessioning_completed
  end
end
