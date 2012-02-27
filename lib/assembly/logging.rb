require 'logger'

module Assembly

  module Logging

    LEVELS = {
      :fatal => Logger::FATAL,
      :error => Logger::ERROR,
      :warn  => Logger::WARN,
      :info  => Logger::INFO,
      :debug => Logger::DEBUG,
    }

    LOG_FORMAT    = "%-6s -- %s -- %s\n"
    TIME_FORMAT   = "%Y-%m-%d %H:%M:%S"

    def self.setup(project_root, environment)
      log_file = File.join project_root, "/log/#{environment}.log"
      @@log       ||= Logger.new(log_file)
      @@log.level   = LEVELS[:info]

      @@log.formatter = proc do |severity, datetime, progname, msg|
        LOG_FORMAT % [severity, datetime.strftime(TIME_FORMAT), msg]
      end
    end

    def log(msg, severity = :info)
      @@log.add Logging::LEVELS[severity], msg
    end

  end

end
