# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative 'config/application'
require 'sneakers/tasks'

Rails.application.load_tasks

unless Rails.env.production?
  require 'rspec/core/rake_task'
  desc 'Run RSpec'
  RSpec::Core::RakeTask.new(:spec)

  require 'rubocop/rake_task'
  desc 'Run rubocop'
  RuboCop::RakeTask.new

  desc 'Run erblint against ERB files'
  task erblint: :environment do
    puts 'Running erblint...'
    system('bundle exec erblint --lint-all --format compact')
  end

  desc 'Run Yarn linter against JS files'
  task eslint: :environment do
    puts 'Running JS linters...'
    system('yarn run lint')
  end

  desc 'Run all configured linters'
  task lint: %i[rubocop erblint eslint]

end
# clear the default task injected by rspec
task(:default).clear

# and replace it with our own
task default: [:rubocop, :spec]
