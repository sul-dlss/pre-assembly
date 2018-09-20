FactoryBot.define do
  factory :job_run do
    job_type { 'discovery_report' }
    output_location { '/path/to/report' }
    association :bundle_context, factory: :bundle_context_with_deleted_output_dir
  end
end
