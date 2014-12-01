#! /usr/bin/env ruby
require File.expand_path(File.dirname(__FILE__) + '/../config/boot')


require 'rubygems'
require 'dor-services'
require 'csv'

current_path = File.dirname(File.expand_path(__FILE__))
output_path = current_path.split("/bin")[0] + "/log/add_status/"
@with_status = CSV.open(output_path+"results.csv",'wb')

@with_status << ['druid', 'status','dor-version','sdr-version']


CSV.foreach(ARGV[0], :headers =>true) do  |row|
  @with_status << [row['druid'], Dor::Item.find(row['druid']).status, row['dor-version'], row['sdr-version']]
end

puts 'Done'