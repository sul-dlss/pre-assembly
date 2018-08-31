set :application, 'pre-assembly'
set :repo_url, 'ssh://git@github.com/sul-dlss/pre-assembly'

set :ssh_options, {
  keys: [Capistrano::OneTimeKey.temporary_ssh_private_key_path],
  forward_agent: true,
  auth_methods: %w(publickey password)
}

# Default branch is :master
ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }.call

# Default deploy_to directory is /var/www/my_app
set :deploy_to, '/opt/app/preassembly/pre-assembly'

# Default value for :scm is :git
# set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
# set :log_level, :debug

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
append :linked_files, 'config/master.key'
# TODO: 'config/honeybadger.yml', database.yml ...

# Default value for linked_dirs is []
append :linked_dirs, 'log', 'config/certs', 'config/cli_environments', 'tmp', 'vendor/bundle'

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5

# update shared_configs before restarting app
before 'deploy:restart', 'shared_configs:update'

set :honeybadger_env, fetch(:stage)

Rake::Task["honeybadger:deploy"].clear
namespace :honeybadger do
  desc 'Notify Honeybadger of the deployment.'
  task :deploy => [:'deploy:set_current_revision'] do
    puts "Temporarily disabling honeybadger deploy notification due to bug with Haml::ActionView. See issue https://github.com/sul-dlss/pre-assembly/issues/98"
    #  from capistrano messages, we get:
    #  "NameError: uninitialized constant Haml::ActionView
    # 01     /opt/app/preassembly/pre-assembly/shared/bundle/ruby/2.4.0/gems/haml-4.0.7/lib/haml/helpers/safe_erubis_template.rb:3:in `<module:Haml>"
    #
    # see https://github.com/haml/haml/issues/974
    #
    # from bundler, can't update to haml 5.0.4:
    # dor-services (~> 5.29) was resolved to 5.29.0, which depends on
    #   active-fedora (< 9.a, >= 6.0) was resolved to 8.5.0, which depends on
    #     rdf-rdfxml (~> 1.1) was resolved to 1.99.0, which depends on
    #       rdf-rdfa (~> 1.99) was resolved to 1.99.1, which depends on
    #         haml (~> 4.0)
  end
end
