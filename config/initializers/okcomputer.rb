# frozen_string_literal: true

# by default, okcomputer does "app up?" and "database conntected?" checks
OkComputer.mount_at = 'status' # use /status or /status/all or /status/<name-of-check>
OkComputer.check_in_parallel = true

OkComputer::Registry.register 'ruby_version', OkComputer::RubyVersionCheck.new

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

class RabbitQueueExistsCheck < OkComputer::Check
  attr_accessor :queue_name, :conn

  def initialize(queue_name)
    self.queue_name = queue_name
    self.conn = Bunny.new(hostname: Settings.rabbitmq.hostname,
                          vhost: Settings.rabbitmq.vhost,
                          username: Settings.rabbitmq.username,
                          password: Settings.rabbitmq.password)
  end

  def check
    conn.start
    if conn.queue_exists?(queue_name)
      mark_message "'#{queue_name}' exists"
    else
      mark_message "'#{queue_name}' does not exist"
      mark_failure
    end
  end
end

if Settings.rabbitmq.enabled
  OkComputer::Registry.register 'rabbit',
                                OkComputer::RabbitmqCheck.new(hostname: Settings.rabbitmq.hostname,
                                                              vhost: Settings.rabbitmq.vhost,
                                                              username: Settings.rabbitmq.username,
                                                              password: Settings.rabbitmq.password)
  OkComputer::Registry.register 'rabbit-queue-preassembly.accession_complete', RabbitQueueExistsCheck.new('preassembly.accession_complete')
end
