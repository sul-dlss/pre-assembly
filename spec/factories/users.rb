FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "fake_#{n}@stanford.edu" }
  end
end
