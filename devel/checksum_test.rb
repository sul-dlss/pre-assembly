#! /usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')

num_files=100
folder='/thumpers/dpgthumper-staging/Revs/PhillipsCollection/content_1951-53'

Dir.chdir(folder)
files=Dir.glob('*')
cs_tool  = Checksum::Tools.new({},:md5,:sha1)
puts "Running checksum test on {num_files} files"

checksumtools=[]
rubychecksums=[]

x=0
start_time = Time.now
while x < num_files do
  file=files[x]
  puts "Checksum tools - File #{x} of #{num_files}: #{file}"
  file=File.join(folder,files[x])
  checksums=cs_tool.digest_file(file)
  checksumtools << checksums
  x+=1
end 
checksumtools_elapsed = Time.now - start_time

x=0
start_time = Time.now
while x < num_files do
  file=files[x]
  puts "Ruby checksums - File #{x} of #{num_files}: #{file}"
  file=File.join(folder,files[x])
  md5=Digest::MD5.file(file).hexdigest
  sha1=Digest::SHA1.file(file).hexdigest
  rubychecksums << {:md5=>md5,:sha1=>sha1}
  x+=1
end 
rubychecksums_elapsed = Time.now - start_time

puts "Running #{num_files} with checksum tools took #{checksumtools_elapsed} seconds"
puts "Running #{num_files} with Ruby digest took #{rubychecksums_elapsed} seconds"

x=0
while x < num_files do
  puts "Checksums for #{files[x]} don't match" unless checksumtools[x][:sha1]==rubychecksums[x][:sha1] && checksumtools[x][:md5]==rubychecksums[x][:md5]
  x+=1  
end