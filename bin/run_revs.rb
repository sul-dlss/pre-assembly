#! /usr/bin/env ruby

require 'rubygems'

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')

def help(msg)
  STDERR.puts msg
  abort "\nUsage: #{$PROGRAM_NAME} BUNDLE_DIR STAGING_DIR"
end

help "Incorrect N of arguments." unless ARGV.size == 2

bundle_dir, staging_dir = ARGV

[bundle_dir, staging_dir].each do |d|
  help "Directory not found: #{d}" unless File.directory? d
end

b = PreAssembly::Bundle.new(
  :bundle_dir          => bundle_dir,
  :manifest            => 'manifest.csv',
  :checksums_file      => 'checksums.txt',
  :project_name        => 'REVS',
  :apo_druid_id        => 'druid:qv648vd4392',
  :collection_druid_id => 'druid:nt028fd5773',
  :staging_dir         => staging_dir,
  :copy_to_staging     => true,
  :cleanup             => true
)

b.run_pre_assembly
