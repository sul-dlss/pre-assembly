# frozen_string_literal: true

# Model representing a Globus destination that can be used as a staging location.
class GlobusDestination < ApplicationRecord
  belongs_to :batch_context, optional: true
  belongs_to :user

  # creates a URL for globus, including the path to the user's destination directory
  def url
    "https://app.globus.org/file-manager?&destination_id=#{Settings.globus.endpoint_id}&destination_path=#{destination_path}"
  end

  # directory within globus including user directory in the format /sunet/datetime
  def destination_path
    "/#{user.sunet_id}/#{created_at.strftime('%Y%m%d%H%M%S')}"
  end

  # path on preassembly filesystem to staged files
  def staging_location
    "#{Settings.globus.directory}#{destination_path}"
  end

  # parse the path from a globus URL e.g. https://app.globus.org/file-manager?&destination_id=f3e29605-7ba5-45f5-8900-f1234566&destination_path=/edsu/20230907044801
  def parse_path(uri)
    params = CGI.parse(URI.parse(uri).query)
    params['destination_path'].first
  end
end
