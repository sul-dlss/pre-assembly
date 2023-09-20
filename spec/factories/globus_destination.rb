# frozen_string_literal: true

FactoryBot.define do
  factory :globus_destination do
    user
    batch_context { nil }

    trait :with_batch_context do
      batch_context
    end
  end
end
