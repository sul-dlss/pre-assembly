# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative 'config/application'
require "sneakers/tasks"

Rails.application.load_tasks

unless Rails.env.production?
  require 'rspec/core/rake_task'
  desc 'Run RSpec'
  RSpec::Core::RakeTask.new(:spec)

  require 'rubocop/rake_task'
  desc 'Run rubocop'
  RuboCop::RakeTask.new
end

# clear the default task injected by rspec
task(:default).clear

# and replace it with our own
task default: [:rubocop, :spec]
