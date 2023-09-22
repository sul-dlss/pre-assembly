# frozen_string_literal: true

# A controller to create Globus Destinations for a user when they click the
# "Request Globus link" button. Perhaps this should be a proper token based API?
class GlobusController < ApplicationController
  # rely fully on Shibboleth for authentication, but don't require CSRF token
  # which makes interaction from JavaScript easier
  skip_before_action :verify_authenticity_token

  def create
    user = current_user
    dest = GlobusDestination.create(user:)
    # TODO: creat the Globus destination!
    render status_code: :created, json: {
      url: dest.url,
      location: dest.staging_location
    }
  end
end
