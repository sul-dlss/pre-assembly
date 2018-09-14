class JobRun < ApplicationRecord
  belongs_to :bundle_context

  validates :job_type, presence: true

  enum job_type: {
    "discovery_report" => 0,
    "preassembly" => 1
  }
end
