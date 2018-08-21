require_relative 'config/application'
require 'rspec/core/rake_task'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

Rails.application.load_tasks

Dir.glob('lib/tasks/*.rake').each { |r| import r }

desc "Run specs"
RSpec::Core::RakeTask.new(:spec)

task :default => :spec

if ['test', 'development'].include? ENV['RAILS_ENV']
  require 'jettywrapper'
  Jettywrapper.hydra_jetty_version = 'v7.3.0' # this keeps us on fedora 3, hydra-jetty v8.x moves to fedora 4.

  def load_order_files(fedora_files)
    data_path = File.expand_path('../fedora_conf/data/', __FILE__)
    fedora_files.delete_if { |f| f.strip.empty? }
    fedora_files.map { |f| File.join(data_path, f.strip) }
  end

  namespace :repo do
    desc "Load XML file(s) into repo (fedora and solr), default: contents of 'load_order' file. With a glob: rake repo:load[fedora_conf/data/*.xml]"
    task :load, [:glob] do |_task, args|
      require 'active_fedora'
      puts "travis_fold:start:repo-load\r" if ENV['TRAVIS'] == 'true'

      file_list = []
      if args.key?(:glob)
        file_list = Dir.glob(args[:glob])
      else
        puts 'No file glob was specified so file order and inclusion is determined by the load_order file'
        fedora_files = File.foreach(File.join(File.expand_path('../fedora_conf/data/', __FILE__), 'load_order')).to_a

        file_list = load_order_files(fedora_files)
      end

      errors = []
      i = 0

      file_list.each do |file|
        i += 1

        handler = proc do |e, _attempt_number, _total_delay|
          puts STDERR.puts "ERROR loading #{file}:\n#{e.message}\n#{e.backtrace.join "\n"}"
          errors << file
        end
        with_retries(:max_tries => 3, :handler => handler, :rescue => [StandardError]) { |attempt|
          puts "** File #{i}, Try #{attempt} ** repo:load foxml=#{file}"
          pid = ActiveFedora::FixtureLoader.import_to_fedora(file)
          ActiveFedora::FixtureLoader.index(pid)
        }
      end
      puts 'Done loading repo files'
      puts "ERROR in #{errors.size()} of #{i} files" if errors.size() > 0
      puts "travis_fold:end:repo-load\r" if ENV['TRAVIS'] == 'true'
    end
  end # :repo
end
