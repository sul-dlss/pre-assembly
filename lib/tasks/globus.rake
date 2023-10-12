# frozen_string_literal: true

namespace :globus do
  desc 'Delete Globus access rules and empty directories'
  task :prune_access, [:sunet_id] => :environment do |_task, args|
    sunet_id = args[:sunet_id]
    globus_destinations = GlobusDestination.joins(:user).where(user: { sunet_id: args[:sunet_id] })
    puts "No GlobusDestinations found for #{sunet_id}" if globus_destinations.empty?
    globus_destinations.each do |dest|
      next if dest.deleted_at.present?

      GlobusCleanup.cleanup_destination(dest)
      puts "Deleted access to globus directory #{dest.destination_path} for #{sunet_id}"
      # Delete empty globus staging locations from the filesystem
      if Dir.empty?(dest.staging_location)
        FileUtils.rm_rf(dest.staging_location)
        puts "Deleted globus staging location #{dest.staging_location}"
      end
    rescue StandardError => e # catch any "Access rule not found" errors from Globus
      puts e
    end
  end
end
