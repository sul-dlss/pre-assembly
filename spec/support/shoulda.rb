# frozen_string_literal: true

Shoulda::Matchers.configure do |configuration|
  configuration.integrate do |with|
    # Choose a test framework:
    with.test_framework :rspec
    with.library :rails
  end
end
