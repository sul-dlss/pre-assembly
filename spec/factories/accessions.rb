# frozen_string_literal: true

FactoryBot.define do
  factory :accession do
    job_run
    druid { 'druid:bc123df4567' }
    state { 'in_progress' }
    version { 1 }
  end
end
