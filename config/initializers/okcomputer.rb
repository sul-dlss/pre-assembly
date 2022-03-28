# frozen_string_literal: true

# by default, okcomputer does "app up?" and "database conntected?" checks
OkComputer.mount_at = 'status' # use /status or /status/all or /status/<name-of-check>
OkComputer.check_in_parallel = true

OkComputer::Registry.register 'ruby_version', OkComputer::RubyVersionCheck.new

# check whether resque workers are working
OkComputer::Registry.register 'feature-resque-down', OkComputer::ResqueDownCheck.new

# check for backed up resque queues: this is a low volume app, so the threshold is low
# 2020-02-20:  Mary Ellen asked for a bigger queue so she could submit a bunch of reports at once.
if Rails.env.production?
  Resque.queues.each do |queue|
    OkComputer::Registry.register "feature-#{queue}-queue-depth", OkComputer::ResqueBackedUpCheck.new(queue, 40)
  end
end

class DirectoryExistsCheck < OkComputer::Check
  attr_accessor :directory

  def initialize(directory)
    self.directory = directory
  end

  def check
    stat = File.stat(directory) if File.exist?(directory)
    if stat
      if stat.directory?
        mark_message "'#{directory}' is a reachable directory"
      else
        mark_message "'#{directory}' is not a directory."
        mark_failure
      end
    else
      mark_message "Directory '#{directory}' does not exist."
      mark_failure
    end
  end
end

# Confirm job_output_parent_dir exists (or else jobs cannot output)
OkComputer::Registry.register 'feature-job_output_parent_dir', DirectoryExistsCheck.new(Settings.job_output_parent_dir)

# spot check tables for data loss
class TablesHaveDataCheck < OkComputer::Check
  def check
    msg = [
      User,
      JobRun,
      BatchContext
    ].map { |klass| table_check(klass) }.join(' ')
    mark_message msg
  end

  private

  # @return [String] message
  def table_check(klass)
    # has at least 1 record
    return "#{klass.name} has data." if klass.any?

    mark_failure
    "#{klass.name} has no data."
  rescue => e # rubocop:disable Style/RescueStandardError
    mark_failure
    "#{e.class.name} received: #{e.message}."
  end
end

OkComputer::Registry.register 'feature-tables-have-data', TablesHaveDataCheck.new

# check for the right number of workers
class WorkerCountCheck < OkComputer::Check
  def check
    expected_count = Settings.expected_worker_count
    actual_count = Resque.workers.count
    message = "#{actual_count} out of #{expected_count} expected workers are up."
    if actual_count >= expected_count
      # this branch is for both == and >, as it is normal for > to happen in 2 cases:
      # 1. very briefly right after a deploy, as hot_swap gracefully shuts down existing workers when they are done
      # 2. when there is a long running job (e.g. production has been known to have them run for 2 days) that hot_swap lets complete
      mark_message message
    else
      mark_failure
      mark_message "only #{message}"
    end
  end
  OkComputer::Registry.register 'feature-worker-count', WorkerCountCheck.new
end

# To make checks optional:
# OkComputer.make_optional %w[feature-resque-down]
