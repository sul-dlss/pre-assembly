require 'fileutils'
require 'erb'



# auto require any project specific files
Dir[File.dirname(__FILE__) + '/pre_assembly/project/*.rb'].each { |file| require "pre_assembly/project/#{File.basename(file)}" }

require 'assembly-utils'
require 'assembly-image'
require 'rest_client'
require 'honeybadger'
