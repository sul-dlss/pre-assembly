# frozen_string_literal: true

FactoryBot.define do
  factory :globus_destination do
    user
    batch_context { nil }

    trait :with_batch_context do
      batch_context
    end

    trait :deleted do
      deleted_at { Time.zone.now }
    end

    trait :stale do
      created_at { 1.month.ago }
      deleted_at { nil }
    end
  end
end
