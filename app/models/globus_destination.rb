# frozen_string_literal: true

DATETIME_FORMAT = '%Y-%m-%d-%H-%M-%S-%L'

# Model representing a Globus destination that can be used as a staging location.
class GlobusDestination < ApplicationRecord
  belongs_to :batch_context, optional: true
  belongs_to :user

  # A helper to look up the GlobusDestination object using a Globus URL
  def self.find_with_globus_url(url)
    uri = URI.parse(url)
    return unless uri.query

    params = CGI.parse(uri.query)
    path = params['destination_path'].first
    return unless path

    match = path.match('^/(.+)/(.+)$')
    return unless match

    sunet_id, created_at = match.captures
    created_at = DateTime.strptime(created_at, DATETIME_FORMAT)
    return unless sunet_id && created_at

    user = User.find_by(sunet_id:)
    GlobusDestination.find_by(user:, created_at:)
  end

  # creates a URL for globus, including the path to the user's destination directory
  def url
    "https://app.globus.org/file-manager?&destination_id=#{Settings.globus.endpoint_id}&destination_path=#{destination_path}"
  end

  # directory within globus including user directory in the format /sunet/datetime
  def destination_path
    "/#{user.sunet_id}/#{created_at.strftime(DATETIME_FORMAT)}"
  end

  # path on preassembly filesystem to staged files
  def staging_location
    "#{Settings.globus.directory}#{destination_path}"
  end
end
