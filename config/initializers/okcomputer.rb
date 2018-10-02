# by default, okcomputer does "app up?" and "database conntected?" checks
OkComputer.mount_at = 'status' # use /status or /status/all or /status/<name-of-check>
OkComputer.check_in_parallel = true

OkComputer::Registry.register 'ruby_version', OkComputer::RubyVersionCheck.new

# check whether resque workers are working
OkComputer::Registry.register 'feature-resque-down', OkComputer::ResqueDownCheck.new

# check for backed up resque queues: this is a low volume app, so the threshold is low
Resque.queues.each do |queue|
  OkComputer::Registry.register "feature-#{queue}-queue-depth", OkComputer::ResqueBackedUpCheck.new(queue, 5)
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

# To make checks optional:
# OkComputer.make_optional %w[feature-resque-down]
