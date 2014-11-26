#! /usr/bin/env ruby
require File.expand_path(File.dirname(__FILE__) + '/../config/boot')


# Run with
# ROBOT_ENVIRONMENT=test bin/FILENAME fetcher-service-url apo-druid

require 'rubygems'
require 'dor-services'
require 'dor-workflow-service'
require 'logger'
require 'dor-fetcher'
require 'csv'

#Set Up the Various Paths
current_path = File.dirname(File.expand_path(__FILE__))
log_path = current_path.split("/bin")[0] + "/log/compare_version/#{Time.now.to_i}/"
results_path = log_path + "results.csv"
@target_repo = "dor"
@target_workflow = "accessionWF"

#Make Sure at least APO Druid was provided
if ARGV.size != 2
  abort("Please supply ARGV in the form of: http://fetcher-service-url.edu druid:apo_pid")
end

#Set up the Overall Run Log
FileUtils.mkdir_p(log_path) 
@run_log = Logger.new(log_path+"run.log")
@run_log.info("Setting up CSV results to be stored at #{results_path}")

#Set Up the Results Output
begin
  @results=  CSV.open(results_path,'wb')
  @results << ['druid','dor-version','sdr-version']
rescue
  @run_log.error("Failed to initialize a results.csv at #{results_path}")
  @run_log.error $!.backtrace
end

#Configure the Fetcher
begin
  fetcher = DorFetcher::Client.new(:service_url => ARGV[0])
rescue
  @run_log.error("Failed to initialize a fetcher with the service url of #{ARGV[0]}")
  @run_log.error $!.backtrace
end

apo = ARGV[1]
@run_log.info("Starting Version Comparsion for objects governed by #{apo}")

#Fetch all the objects governed by this APO
begin
  objects_hash = fetcher.get_apo(apo)
rescue 
  @run_log.error("#{apo} failed.  Possibly an invalid druid.")
  @run_log.error $!.backtrace
end
  
@run_log.info("Fetcher Returned:\n\n\n\n\n\n#{objects_hash}\n\n\n\n\n\n")
druids = fetcher.druid_array(objects_hash)-[apo]  
@run_log.info("#{druids.size} records returned for APO #{apo}")

druids.each do |druid|
    begin
      item = Dor::Item.find(druid)
    rescue
      @run_log.error("The object #{druid} was not found via Dor::Item.find(pid).")
      next #Skip to the next druid
    end
    dor_version = item.current_version.to_i #gets current dor version
    sdr_version = -1 #TODO: Run a curl request to fix this
    @results << [druid, dor_version, sdr_version]
end
@run_log.info("Completed version fixes for #{apo}")

