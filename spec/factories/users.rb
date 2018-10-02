FactoryBot.define do
  factory :user do
    sequence(:sunet_id) { |n| "fake_#{n}" }
  end
end
