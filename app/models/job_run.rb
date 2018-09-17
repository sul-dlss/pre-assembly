class JobRun < ApplicationRecord
  belongs_to :bundle_context
  validates :job_type, presence: true
  after_create :enqueue!
  after_update :send_notification, if: -> { saved_change_to_output_location? }

  enum job_type: {
    "discovery_report" => 0,
    "preassembly" => 1
  }

  # throw to asynchronous processing via correct Job class for job_type
  # @return [ApplicationJob, nil] nil if unpersisted
  def enqueue!
    return nil unless persisted?
    "#{job_type.camelize}Job".constantize.perform_later(self)
  end

  def send_notification
    return unless output_location
    JobMailer.with(job_run: self).completion_email.deliver_later
  end

end
