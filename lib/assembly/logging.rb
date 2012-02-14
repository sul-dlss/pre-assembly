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

    @@log       ||= Logger.new(STDOUT)
    @@log.level   = LEVELS[:info]
    LOG_FORMAT    = "%-6s -- %s -- %s\n"

    @@log.formatter = proc do |severity, datetime, progname, msg|
      LOG_FORMAT % [severity, datetime.strftime("%Y-%m-%d %H:%M:%S"), msg]
    end

    def log(msg, severity = :info)
      @@log.add Logging::LEVELS[severity], msg
    end

  end

end
