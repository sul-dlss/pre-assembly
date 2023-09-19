# frozen_string_literal: true

FactoryBot.define do
  factory :job_run do
    project factory: %i[project_with_deleted_output_dir]
    state { 'waiting' }

    trait :preassembly do
      job_type { 'preassembly' }
    end

    trait :discovery_report do
      job_type { 'discovery_report' }
      output_location { '/path/to/report' }
    end
  end
end
