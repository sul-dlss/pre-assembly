module PreAssembly

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
      log_file = File.join(project_root, 'log', "#{environment}.log")
      @@log       ||= Logger.new(log_file)
      @@log.level   = LEVELS[:info]

      @@log.formatter = proc do |severity, datetime, progname, msg|
        LOG_FORMAT % [severity, datetime.strftime(TIME_FORMAT), msg]
      end
    end

    def log(msg, severity = :info)
      @@log.add Logging::LEVELS[severity], msg
    end
    
    def self.seconds_to_string(s)
 
      # d = days, h = hours, m = minutes, s = seconds
      m = (s / 60).floor
      s = s % 60
      h = (m / 60).floor
      m = m % 60
      d = (h / 24).floor
      h = h % 24
 
      output = "#{s} second#{self.pluralize(s)}" if (s > 0)
      output = "#{m} minute#{self.pluralize(m)}, #{s} second#{self.pluralize(s)}" if (m > 0)
      output = "#{h} hour#{self.pluralize(h)}, #{m} minute#{self.pluralize(m)}, #{s} second#{self.pluralize(s)}" if (h > 0)
      output = "#{d} day#{self.pluralize(d)}, #{h} hour#{self.pluralize(h)}, #{m} minute#{self.pluralize(m)}, #{s} second#{self.pluralize(s)}" if (d > 0)
 
      return output
    end
 
    def self.pluralize number 
      return "s" unless number == 1
      return ""
    end

  end

end
