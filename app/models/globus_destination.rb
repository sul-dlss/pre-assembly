# frozen_string_literal: true

# Model representing a Globus destination that can be used as a staging location.
class GlobusDestination < ApplicationRecord
  belongs_to :batch_context, optional: true
  belongs_to :user
  after_initialize :set_directory

  scope :active, -> { where(deleted_at: nil) }
  scope :older_than, ->(time) { where('created_at < ?', time) }

  # A helper method to find potential Globus Destinations to cleanup
  def self.find_stale(timeframe)
    active.older_than(timeframe)
  end

  # A helper to look up the GlobusDestination object using a Globus URL.
  # @param url [String] a Globus URL
  # @return [GlobusDestination, nil] the GlobusDestination found or nil
  def self.find_with_globus_url(url)
    path = extract_path(url)
    return unless path

    _, sunet_id, directory = path.split('/')
    user = User.find_by(sunet_id:)
    find_by(user:, directory:)
  end

  # Extract the path from either destination_path or origin_path depending on
  # whether origin_id or destination_id has the configured globus-endpoint-id.
  # This allows users to paste in a Globus viewer URL that they may have been
  # emailed which flips around the destination_path to the origin_path, and also
  # will find when they may have flipped the origin/destination in the viewer.
  # @param url [String] a Globus URL
  # @return [String, nil] the path value, or nil if not found
  def self.extract_path(url)
    uri = URI.parse(url)
    return unless uri.query

    params = CGI.parse(uri.query)
    endpoint_param = if params['origin_id']&.first == Settings.globus.endpoint_id
                       'origin_path'
                     else
                       'destination_path'
                     end

    params[endpoint_param]&.first
  end

  # Creates a URL for globus, including the path to the user's destination directory
  def url
    "https://app.globus.org/file-manager?&destination_id=#{Settings.globus.endpoint_id}&destination_path=#{destination_path}"
  end

  # Get the directory within globus including user directory in the format /sunet/datetime
  def destination_path
    "/#{user.sunet_id}/#{directory}"
  end

  # Get the path on preassembly filesystem to staged files
  def staging_location
    "#{Settings.globus.directory}#{destination_path}"
  end

  # Set the default directory name using current time (when not already set)
  def set_directory
    self.directory = DateTime.now.strftime('%Y-%m-%d-%H-%M-%S-%L') unless directory
  end
end
