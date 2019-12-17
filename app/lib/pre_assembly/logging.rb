# frozen_string_literal: true

module PreAssembly
  module Logging
    LEVELS = {
      fatal: Logger::FATAL,
      error: Logger::ERROR,
      warn: Logger::WARN,
      info: Logger::INFO,
      debug: Logger::DEBUG
    }.freeze

    LOG_FORMAT    = "%-6s -- %s -- %s\n"
    TIME_FORMAT   = '%Y-%m-%d %H:%M:%S'

    @@log       ||= Logger.new(File.join(Rails.root, 'log', "#{Rails.env}.log"))
    @@log.level   = LEVELS[:info]

    @@log.formatter = proc do |severity, datetime, _progname, msg|
      format(LOG_FORMAT, severity, datetime.strftime(TIME_FORMAT), msg)
    end

    def log(msg, severity = :info)
      @@log.add Logging::LEVELS[severity], msg
    end
  end
end
