FactoryBot.define do
  factory :user do
    sequence(:sunet_id) { |n| "fake_#{n}@stanford.edu" } # TODO: migrate this to an `email` field
  end
end
