# frozen_string_literal: true

FactoryBot.define do
  factory :job_run do
    job_type { 'discovery_report' }
    output_location { '/path/to/report' }
    association :batch_context, factory: :batch_context_with_deleted_output_dir
  end
end
