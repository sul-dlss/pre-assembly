class JobRun < ApplicationRecord
  belongs_to :bundle_context

  enum job_type: {
    "discovery_report" => 0,
    "pre_assembly" => 1
  }
end
