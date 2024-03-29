# frozen_string_literal: true

class ApplicationController < ActionController::Base # rubocop:disable Style/Documentation
  before_action :authenticate_user! # ensures that remote user is logged in locally (via database)
end
