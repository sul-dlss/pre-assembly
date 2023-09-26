# frozen_string_literal: true

# A controller to create Globus Destinations for a user when they click the
# "Request Globus link" button. Perhaps this should be a proper token based API?
class GlobusController < ApplicationController
  # rely fully on Shibboleth for authentication, but don't require CSRF token
  # which makes interaction from JavaScript easier
  skip_before_action :verify_authenticity_token

  def create
    @user = current_user
    @dest = GlobusDestination.create(user: @user)
    create_globus_endpoint

    render status_code: :created, json: {
      url: @dest.url,
      location: @dest.staging_location
    }
  end

  private

  def create_globus_endpoint
    return true if test_mode?

    user_id = "#{@user.sunet_id}@stanford.edu"
    success = GlobusClient.mkdir(path: @dest.destination_path, user_id:)
    raise "Error creating globus endpoint for destination #{@dest.id} for #{user_id}" unless success
  end

  # simulate globus calls in development if settings indicate we should for testing
  def test_mode?
    Settings.globus.test_mode && Rails.env.development?
  end
end
