# NOTE: This script references the dor-fetcher gem, which is now commented out in the Gemfile since it is no longer supported
#  If this script needs to be re-run, seek an upgrade path for the functionality provided by dor-services (getting druids goverened by an APO)
#  Peter Mangiafico July 2016

# ! /usr/bin/env ruby
require File.expand_path(File.dirname(__FILE__) + '/../config/boot')

# Run with
# RAILS_ENV=test devel/FILENAME fetcher-service-url apo-druid sdr-url sdr-user-name sdr-password

require 'rubygems'
require 'dor-services'
require 'dor-workflow-service'
require 'logger'
require 'dor-fetcher'
require 'csv'
require 'nokogiri'

# Set Up the Various Paths
time_now = Time.now.getlocal.to_s
time_stamp = time_now[0..time_now.size - 7]
current_path = File.dirname(File.expand_path(__FILE__))
log_path = current_path.split("/devel")[0] + "/log/get_dor_and_sdr_versions/#{time_stamp}/"

results_path = log_path + "results.csv"
mismatch_results_path = log_path + "mismatch_results.csv"
@target_repo = "dor"
@target_workflow = "accessionWF"

# Make Sure at least APO Druid was provided
if ARGV.size != 5
  abort("Please supply ARGV in the form of: http://fetcher-service-url.edu druid:apo_pid http://sdr-service-url.edu sdrUserName sdrPassword")
end

# Set up the Overall Run Log
FileUtils.mkdir_p(log_path)
@run_log = Logger.new(log_path + "run.log")
@run_log.info("Setting up CSV results to be stored at #{results_path}")

# Set Up the Results Output
begin
  @results = CSV.open(results_path, 'wb')
  @results << ['druid', 'status', 'dor-version', 'sdr-version']
  @mismatch_results = CSV.open(mismatch_results_path, 'wb')
  @mismatch_results << ['druid', 'status', 'dor-version', 'sdr-version']
rescue
  @run_log.error("Failed to initialize a results.csv at #{results_path}")
  @run_log.error $!.backtrace
end

# Configure the Fetcher
begin
  fetcher = DorFetcher::Client.new(:service_url => ARGV[0])
rescue
  @run_log.error("Failed to initialize a fetcher with the service url of #{ARGV[0]}")
  @run_log.error $!.backtrace
end

apo = ARGV[1]

# Add on the druid prefix if it is not present
if apo.split("druid:").size == 1
  apo = "druid:" + apo
  @run_log.info("Added the druid: prefix to the apo for a result of #{apo}")
end

@run_log.info("Starting Version Comparsion for objects governed by #{apo}")

# Fetch all the objects governed by this APO
begin
  objects_hash = fetcher.get_apo(apo)
rescue
  @run_log.error("#{apo} failed.  Possibly an invalid druid.")
  @run_log.error $!.backtrace
end

@run_log.info("Fetcher Returned:\n\n\n\n\n\n#{objects_hash}\n\n\n\n\n\n")
druids = fetcher.druid_array(objects_hash) - [apo]
@run_log.info("#{druids.size} records returned for APO #{apo}")

druids.each do |druid| # TODO: Threach me
  # Get The Dor Version
  begin
    item = Dor::Item.find(druid)
  rescue
    @run_log.error("The object #{druid} was not found via Dor::Item.find(pid).")
    next # Skip to the next druid
  end
  dor_version = item.current_version.to_i # gets current dor version

  # Get SDR Version
  begin
    r = Nokogiri::HTML(open("#{ARGV[2]}/sdr/objects/#{druid}/current_version", :http_basic_authentication => ["#{ARGV[3]}", "#{ARGV[4]}"]))
    sdr_version = r.xpath('//currentversion').children.first.text.to_i
  rescue
    @run_log.error("The object #{druid} failed to a return sdr_version")
    next # Skip to the next druid
  end

  @results << [druid, item.status, dor_version, sdr_version]

  if dor_version != sdr_version
    @mismatch_results << [druid, item.status, dor_version, sdr_version]
  end
end
@run_log.info("Completed version fixes for #{apo}")
