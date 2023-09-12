# frozen_string_literal: true

# Wait for an accession into SDR.
class AccessionCompleteJob
  include Sneakers::Worker
  # This worker will connect to "preassembly.accession_complete" queue
  # env is set to nil since by default the actual queue name would be
  # "preassembly.accession_complete_development"
  from_queue 'preassembly.accession_complete', env: nil

  # This will receive both accession end-accession.completed and *.error messages.
  # They may not be for preassembly items.
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  def work(msg)
    @msg = JSON.parse(msg)
    Honeybadger.context(msg:)

    # Without this, the database connection pool gets exhausted
    ActiveRecord::Base.connection_pool.with_connection do
      if completed?
        # If completed, only update when in progress or failed.
        accessions = Accession.where(druid:, version:, state: %w[in_progress failed])
        state = 'completed'
      elsif error?
        # If error, only update when in progress.
        accessions = Accession.where(druid:, version:, state: 'in_progress')
        state = 'failed'
      else
        raise "Unexpected message status for #{msg}"
      end

      update_accessions(accessions, state)
      start_job_run_complete_jobs(accessions)
    end

    ack!
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength

  attr_reader :msg

  def update_accessions(accessions, state)
    accessions.map { |accession| accession.update!(state:) }
  end

  def start_job_run_complete_jobs(accessions)
    job_runs = accessions.map(&:job_run).uniq
    job_runs.each { |job_run| JobRunCompleteJob.perform_later(job_run) }
  end

  def druid
    @druid ||= msg.fetch('druid').delete_prefix('druid:')
  end

  def version
    @version ||= msg.fetch('version').to_i
  end

  def error?
    msg.fetch('status') == 'error'
  end

  def completed?
    msg.fetch('status') == 'completed'
  end
end
