# frozen_string_literal: true

# Learn more: http://github.com/javan/whenever
require_relative 'environment'

set :output, 'log/cron.log'

# These define jobs that checkin with Honeybadger.
# If changing the schedule of one of these jobs, also update at https://app.honeybadger.io/projects/52900/check_ins
job_type :runner_hb,
         'cd :path && bin/rails runner -e :environment ":task" :output && curl --silent https://api.honeybadger.io/v1/check_in/:check_in'

# extract and then load everything into the database
every 1.day, at: '1:00am' do
  set :check_in, Settings.honeybadger_checkins.globus_cleanup
  runner_hb 'GlobusCleanup.run'
end
