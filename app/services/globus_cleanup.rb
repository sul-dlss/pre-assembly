# frozen_string_literal: true

# Removes globus access rules for completed accessioning jobs and unused destinations
# Run regularly via cron, scheduled with whenever gem
class GlobusCleanup
  def self.run
    cleanup_stale_completed
    cleanup_stale_unused
  end

  # Removes globus access rules for completed accessioning jobs
  def self.cleanup_stale_completed
    GlobusDestination.find_stale(1.week.ago).each do |dest|
      next unless dest.batch_context&.accessioning_complete?

      cleanup_destination(dest)
    end
  end

  # Removes globus access rules for unused destinations that don't have an associated batch context
  def self.cleanup_stale_unused
    GlobusDestination.find_stale(1.month.ago).each do |dest|
      next if dest.batch_context.present?

      cleanup_destination(dest)
    end
  end

  # Delete the given globus destination access rule and mark as deleted locally
  def self.cleanup_destination(dest)
    user_id = "#{dest.user.sunet_id}@stanford.edu"
    GlobusClient.delete_access_rule(path: dest.destination_path, user_id:)
    dest.update!(deleted_at: Time.zone.now)
    Rails.logger.info("GlobusCleanup done for globus_destination #{dest.id})")
  rescue StandardError => e # catch any "Access rule not found" errors from Globus
    Honeybadger.notify(e, context: { message: 'GlobusCleanup failed', globus_destination_id: dest.id })
  end
end
