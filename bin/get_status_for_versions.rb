#! /usr/bin/env ruby
require File.expand_path(File.dirname(__FILE__) + '/../config/boot')


require 'rubygems'
require 'dor-services'
require 'csv'
require 'fileutils'
require 'pathname'


current_path = File.dirname(File.expand_path(__FILE__))
output_path = current_path.split("/bin")[0] + "/log/add_status/"
FileUtils::mkdir_p  output_path
@with_status = CSV.open(output_path+Pathname.new(ARGV[0]).basename.to_s,'wb')

@with_status << ['druid', 'status','dor-version','sdr-version']

i = 0
info_blurb = 1000
CSV.foreach(ARGV[0], :headers =>true) do  |row|
  @with_status << [row['druid'], Dor::Item.find(row['druid']).status, row['dor-version'], row['sdr-version']]
  i += 1
  puts "#{i} complete" if i % info_blurb == 0 
end

puts 'Done'