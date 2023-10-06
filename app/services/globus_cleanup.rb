# frozen_string_literal: true

# Removes globus access rules for completed accessioning jobs
# Run regularly via cron, scheduled with whenever gem
class GlobusCleanup
  def self.run
    GlobusDestination.find_stale do |dest|
      next unless dest.batch_context.job_runs.any?(&:accessioning_complete?)

      cleanup_destination(dest)
      Rails.logger.info("GlobusCleanup done for batch_context #{dest.batch_context.id}, globus_destination #{dest.id})")
    rescue StandardError => e # catch any "Access rule not found" errors from Globus
      Honeybadger.notify(e, context: { message: 'GlobusCleanup failed', globus_destination_id: dest.id, batch_context_id: dest.batch_context.id })
    end
  end

  # Delete the given globus destination
  def self.cleanup_destination(dest)
    GlobusClient.delete_access_rule(path: dest.destination_path, user_id: "#{dest.batch_context.user.sunet_id}@stanford.edu")
    dest.update!(deleted_at: Time.zone.now)
  end
  private_class_method :cleanup_destination
end
