# frozen_string_literal: true

# Model class for the database table job_runs;
#  contains information about a specific pre-assembly or discovery report run; parameters used for that run are in the associated BatchContext
#  the user is able to instantiate multiple jobs (the same and/or different types) using the same BatchContext and each will get its own JobRun
class JobRun < ApplicationRecord
  belongs_to :batch_context
  has_many :accessions, dependent: :destroy
  validates :job_type, presence: true
  validates :state, presence: true
  after_initialize :default_enums
  after_create_commit :enqueue!

  delegate :progress_log_file, :progress_log_file_exists?, to: :batch_context

  enum job_type: {
    'discovery_report' => 0,
    'preassembly' => 1
  }

  state_machine initial: :waiting do
    event :started do
      transition waiting: :running
    end

    # signifies the entire job could not be run (e.g. bad manifest supplied)
    event :failed do
      transition running: :failed
    end

    # signifies the job ran through, but at least one object had an error of some kind (e.g. network blip)
    event :completed_with_errors do
      transition running: :discovery_report_complete_with_errors, if: :discovery_report?
      transition running: :preassembly_complete_with_errors, if: :preassembly?
    end

    event :completed do
      transition running: :discovery_report_complete, if: :discovery_report?
      transition running: :preassembly_complete, if: :preassembly?
    end
    after_transition on: [:completed, :completed_with_errors, :failed], do: :send_preassembly_notification

    event :accessioning_completed do
      transition preassembly_complete: :accessioning_complete
      transition preassembly_complete_with_errors: :accessioning_complete
    end
    after_transition on: [:accessioning_completed], do: :send_accessioning_notification
  end

  # send to asynchronous processing via correct Job class for job_type
  # @return [ApplicationJob, nil] nil if unpersisted
  def enqueue!
    return nil unless persisted?

    "#{job_type.camelize}Job".constantize.perform_later(self)
  end

  # the states that indicate this job is either not started or is currently running
  def in_progress?
    (waiting? || running?)
  end

  # indicates if the discovery report job is ready for display and is available (some jobs may fail, leaving no report)
  def report_ready?
    job_type == 'discovery_report' && !in_progress? && output_location && File.exist?(output_location)
  end

  # @return [DiscoveryReport]
  def to_discovery_report
    @to_discovery_report ||= DiscoveryReport.new(batch)
  end

  # return [PreAssembly::Batch]
  def batch
    @batch ||= if batch_context.using_file_manifest
                 PreAssembly::Batch.new(self, file_manifest:)
               else
                 PreAssembly::Batch.new(self)
               end
  end

  def file_manifest
    PreAssembly::FileManifest.new(csv_filename: batch_context.file_manifest_path,
                                  staging_location: batch_context.staging_location)
  end

  private

  def default_enums
    self[:job_type] ||= 0
  end

  def send_preassembly_notification
    JobMailer.with(job_run: self).completion_email.deliver_later
  end

  def send_accessioning_notification
    JobMailer.with(job_run: self).accession_completion_email.deliver_later
  end
end
