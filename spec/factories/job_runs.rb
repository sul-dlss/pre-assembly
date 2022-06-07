# frozen_string_literal: true

FactoryBot.define do
  factory :job_run do
    output_location { '/path/to/report' }
    association :batch_context, factory: :batch_context_with_deleted_output_dir

    trait :preassembly do
      job_type { 'preassembly' }
    end

    trait :discovery_report do
      job_type { 'discovery_report' }
    end
  end
end
