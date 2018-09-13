# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative 'config/application'
Rails.application.load_tasks

task :travis_setup_postgres do
  sh("psql -f db/scripts/preassembly_test_setup.sql postgres")
end
