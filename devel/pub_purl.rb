#!/usr/bin/env ruby
#
require File.expand_path(File.dirname(__FILE__) + '/../config/boot')

current_path = File.dirname(File.expand_path(__FILE__))

require 'rubygems'
require 'dor-services'
require 'assembly-utils'
require 'logger'


@base_path = '/home/lyberadmin/jlavigne/BnF/update/'
@mods_path = @base_path + 'mods/'
@log_path = @base_path + 'logs/'

@log = Logger.new( @log_path + 'pub_md_log', 'daily' )

##########################
def get_file_path(file)
###########################

  if file !~ /#{@base_path}/
    file = @base_path + file
  end

  return file

end # get_file_path

####################
def check_args(args)
####################

 if args.size != 1
   return -1
 elsif ! File.exists?(get_file_path(args[0]))
    return -1
 else
    return 0
 end

end # check_args


##########
def main() # Iterate over file of pid/druids to publish metadata for
##########

  if check_args(ARGV) != 0
    puts "Please enter the name of a file of pids to process."
    exit
  end

  File.open(get_file_path(ARGV[0])).each do |pid|

      i=0
      num_attempts=5 # number of attempts before crash
      sleep_time=30 # time between attempts
      success=false
      backtrace=""
      exception_message=""
      until i == num_attempts || success do
        i+=1
        begin
          # RUN YOUR CODE HERE
          pid.chomp!
          @log.info '====================='
          @log.info "#{Time.now.to_s}"
          @log.info "Processing pid #{pid}"
          obj = Dor::Item.find(pid)
          obj.publish_metadata
	  success=true # IF IT WORKS
        rescue Exception => e
          @log.error "      ** BOOM **, trying again in #{sleep_time} seconds"
          backtrace=e.backtrace
          exception_message=e.message
          sleep sleep_time
        end
      end
      
      if success == false
        error_message = "failure after #{i} attempts \n"
        error_message += "exception: #{exception_message}\n"
        error_message += "backtrace: #{backtrace}" 
        raise error_message
      end

  end

end

main()
