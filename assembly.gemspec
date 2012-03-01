$:.push File.expand_path("../lib", __FILE__)
require "assembly/version"

Gem::Specification.new do |s|
  s.name        = 'assembly'
  s.version     = Assembly::VERSION
  s.authors     = ["Peter Mangiafico", "Renzo Sanchez-Silva","Monty Hindman","Tony Calavano"]
  s.email       = ["pmangiafico@stanford.edu"]
  s.homepage    = ""
  s.summary     = %q{Ruby immplementation of services needed to prepare objects to be accessioned in SULAIR digital library}
  s.description = %q{Contains classes to create symlinks, create derivative files, parse incoming CSV files } + 
                  %q{to register objects, create content meta-data and perform other services needed for assembly}

  s.rubyforge_project = 'assembly'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_dependency 'mini_exiftool'
  s.add_dependency 'uuidtools'
  s.add_dependency 'nokogiri'
  s.add_dependency 'csv-mapper'
  s.add_dependency 'dor-services'
  s.add_dependency 'lyber-core', "~> 1.3.0"

  s.add_development_dependency "rspec", "~> 2.6"
end
